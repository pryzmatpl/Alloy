"""Core compile/check/run logic for the Alloy CLI."""

import base64
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from . import acp, providers
from .config import apply_cli_overrides, load_config


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _system_prompt() -> str:
    path = _repo_root() / "COMPILER_SYSTEM.md"
    if path.exists():
        return path.read_text(encoding="utf-8")
    return "You are the Alloy v0.2 compiler. Return only JSON ACP responses."


def _out_dir(package_dir: Path, target: str) -> Path:
    return package_dir / "target" / target.replace("-", "_")


def _native(target: str) -> bool:
    return not target.startswith("wasm32")


def _find_c_artifact(artifacts: list[dict[str, Any]]) -> dict[str, Any] | None:
    for a in artifacts:
        if a.get("name", "").endswith(".c"):
            return a
    return None


def _compile_c_to_exe(
    c_path: Path, exe_path: Path, opt_level: int, link_flags: list[str] | None = None
) -> None:
    cc = shutil.which("gcc") or shutil.which("clang") or "cc"
    cmd = [cc, f"-O{opt_level}", str(c_path), "-o", str(exe_path)]
    if link_flags:
        cmd.extend(link_flags if isinstance(link_flags, list) else [link_flags])
    subprocess.run(cmd, check=True)


def do_compile(
    package_dir: Path,
    args: Any,
    passes: list[str],
) -> dict[str, Any]:
    """Build an ACP request, call the LLM, validate and return the response."""
    config = load_config(package_dir)
    config = apply_cli_overrides(config, args)

    target = config["target"]
    emit = config["emit"]
    opt_level = config["opt_level"]
    compiler_cfg = config.get("compiler", {})

    req = acp.build_request(
        package_dir=package_dir,
        target=target,
        passes=passes,
        emit=emit,
        opt_level=opt_level,
    )

    messages = [
        {"role": "system", "content": _system_prompt()},
        {"role": "user", "content": acp.request_to_json(req)},
    ]

    content = providers.chat_completion(
        base_url=compiler_cfg.get("base_url", "http://localhost:11434/v1"),
        api_key=compiler_cfg.get("api_key", ""),
        model=compiler_cfg.get("model", "qwen2.5-coder:7b"),
        messages=messages,
        temperature=0.0,
    )

    resp = providers.extract_json(content)
    acp.validate_response(resp)
    resp["_req"] = req
    resp["_config"] = config
    resp["_package_dir"] = package_dir
    return resp


def write_artifacts(resp: dict[str, Any], out_dir: Path) -> list[Path]:
    """Write response artifacts to the build directory."""
    out_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for a in resp.get("artifacts", []):
        name = a["name"]
        content = a["content"]
        path = out_dir / name
        if a.get("encoding") == "base64":
            path.write_bytes(base64.b64decode(content))
        else:
            path.write_text(content, encoding="utf-8")
        written.append(path)
        print(f"  wrote {path}")
    return written


def maybe_compile_executable(resp: dict[str, Any]) -> Path | None:
    """If emit=c and target is native, compile the emitted C file to a binary."""
    config = resp["_config"]
    emit = config["emit"]
    target = config["target"]
    if emit != "c" or not _native(target):
        return None

    package_dir = resp["_package_dir"]
    out_dir = _out_dir(package_dir, target)
    c_art = _find_c_artifact(resp.get("artifacts", []))
    if c_art is None:
        return None

    c_path = out_dir / c_art["name"]
    exe_name = resp["_req"]["package"]["name"]
    if target.endswith("windows-msvc"):
        exe_name += ".exe"
    exe_path = out_dir / exe_name

    link_flags = config.get("link_flags")
    _compile_c_to_exe(c_path, exe_path, config["opt_level"], link_flags)
    print(f"  compiled {c_path} -> {exe_path}")
    return exe_path


def print_diagnostics(resp: dict[str, Any]) -> bool:
    """Print diagnostics; return True if any error-level diagnostic exists."""
    has_error = False
    for d in resp.get("diagnostics", []):
        loc = ""
        if d.get("file"):
            loc = f"{d['file']}:{d.get('line', '?')}:{d.get('column', '?')}: "
        print(f"{d['level']}: {loc}{d['message']}")
        if d["level"] == "error":
            has_error = True
    return has_error


def check(package_dir: Path, args: Any) -> int:
    try:
        resp = do_compile(package_dir, args, passes=["typecheck"])
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    has_error = print_diagnostics(resp)
    if resp.get("status") == "error" or has_error:
        print("alloy check: failed")
        return 1
    print("alloy check: ok")
    return 0


def build(package_dir: Path, args: Any) -> int:
    try:
        resp = do_compile(package_dir, args, passes=["typecheck", "lower", "emit"])
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    has_error = print_diagnostics(resp)
    if resp.get("status") == "error" or has_error:
        print("alloy build: failed")
        return 1

    req = resp["_req"]
    target = req["target"]
    package_dir_actual = resp["_package_dir"]
    out_dir = _out_dir(package_dir_actual, target)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Also write IR field if present
    if resp.get("ir"):
        ir_path = out_dir / f"{req['package']['name']}.alir"
        ir_path.write_text(resp["ir"], encoding="utf-8")
        print(f"  wrote {ir_path}")

    write_artifacts(resp, out_dir)

    if args.emit == "c" or (args.emit is None and resp["_config"]["emit"] == "c"):
        maybe_compile_executable(resp)

    print(f"alloy build --target {target}: ok")
    return 0


def run(package_dir: Path, args: Any) -> int:
    # Force emit=c so we can compile and execute
    if args.emit is None:
        args.emit = "c"

    try:
        resp = do_compile(package_dir, args, passes=["typecheck", "lower", "emit"])
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    has_error = print_diagnostics(resp)
    if resp.get("status") == "error" or has_error:
        print("alloy run: failed")
        return 1

    req = resp["_req"]
    target = req["target"]
    package_dir_actual = resp["_package_dir"]
    out_dir = _out_dir(package_dir_actual, target)
    out_dir.mkdir(parents=True, exist_ok=True)

    if resp.get("ir"):
        ir_path = out_dir / f"{req['package']['name']}.alir"
        ir_path.write_text(resp["ir"], encoding="utf-8")
        print(f"  wrote {ir_path}")

    write_artifacts(resp, out_dir)

    exe_path = maybe_compile_executable(resp)
    if exe_path is None:
        print("error: no native executable produced", file=sys.stderr)
        return 1

    print(f"  running {exe_path}")
    result = subprocess.run([str(exe_path)])
    return result.returncode


def init(target_dir: Path, _args: Any) -> int:
    if not target_dir.exists():
        target_dir.mkdir(parents=True)
    manifest = target_dir / "alloy.toml"
    src = target_dir / "src"
    main = src / "main.al"

    if manifest.exists():
        print(f"error: {manifest} already exists", file=sys.stderr)
        return 1

    manifest.write_text(
        '[package]\nname = "hello"\nversion = "0.2.0"\nkind = "bin"\n\n[compiler]\nprovider = "ollama"\nmodel = "qwen2.5:0.5b"\nbase_url = "http://localhost:11434/v1"\n',
        encoding="utf-8",
    )
    src.mkdir(exist_ok=True)
    main.write_text(
        'use std.io.{Writer, write_str, register_io};\nuse std.di.Container;\n\nfunction main(): i32 {\n    let di = Container();\n    register_io(di);\n    let out: Writer = di.get<Writer>();\n    match write_str(out, "Hello, world!\\n") {\n        Ok(_)  => { return 0; }\n        Err(_) => { return 1; }\n    }\n}\n',
        encoding="utf-8",
    )
    print(f"initialized Alloy package at {target_dir}")
    return 0
