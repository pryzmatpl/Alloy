"""Alloy Compilation Protocol helpers."""

import json
from pathlib import Path
from typing import Any


PROTOCOL = "acp/0.2"
VALID_PASSES = {"typecheck", "lower", "emit"}
VALID_EMIT = {"ir", "assembly", "c", "wasm", "object"}


def collect_package(package_dir: Path) -> dict[str, Any]:
    """Read alloy.toml and every .al file under src/."""
    manifest = package_dir / "alloy.toml"
    if not manifest.exists():
        raise FileNotFoundError(f"No alloy.toml found in {package_dir}")

    files: dict[str, str] = {"alloy.toml": manifest.read_text(encoding="utf-8")}

    src = package_dir / "src"
    if src.exists():
        for path in sorted(src.rglob("*.al")):
            rel = path.relative_to(package_dir).as_posix()
            files[rel] = path.read_text(encoding="utf-8")

    # Minimal package metadata from manifest text (full TOML is already present).
    import tomllib

    with manifest.open("rb") as f:
        data = tomllib.load(f)
    package = data.get("package", {})
    return {
        "name": package.get("name", package_dir.name),
        "kind": package.get("kind", "bin"),
        "files": files,
    }


def build_request(
    package_dir: Path,
    target: str,
    passes: list[str],
    emit: str = "c",
    opt_level: int = 0,
) -> dict[str, Any]:
    """Build an ACP/0.2 request object."""
    if not set(passes).issubset(VALID_PASSES):
        raise ValueError(f"Invalid passes: {passes}. Valid: {sorted(VALID_PASSES)}")
    if emit not in VALID_EMIT:
        raise ValueError(f"Invalid emit: {emit}. Valid: {sorted(VALID_EMIT)}")

    package = collect_package(package_dir)
    return {
        "protocol": PROTOCOL,
        "package": package,
        "target": target,
        "passes": passes,
        "options": {"opt_level": opt_level, "emit": emit},
    }


def validate_response(obj: Any) -> dict[str, Any]:
    """Basic structural validation of an ACP response."""
    if not isinstance(obj, dict):
        raise ValueError("Response must be a JSON object")
    if obj.get("protocol") != PROTOCOL:
        raise ValueError(f"Response protocol must be {PROTOCOL}")
    status = obj.get("status")
    if status not in ("ok", "error"):
        raise ValueError("Response status must be 'ok' or 'error'")

    diagnostics = obj.get("diagnostics", [])
    if not isinstance(diagnostics, list):
        raise ValueError("diagnostics must be a list")
    for d in diagnostics:
        if d.get("level") not in ("error", "warning", "info"):
            raise ValueError(f"Invalid diagnostic level: {d}")
        if not isinstance(d.get("message", ""), str):
            raise ValueError("diagnostic message must be a string")

    artifacts = obj.get("artifacts", [])
    if not isinstance(artifacts, list):
        raise ValueError("artifacts must be a list")
    for a in artifacts:
        if not isinstance(a.get("name", ""), str):
            raise ValueError("artifact name must be a string")
        if not isinstance(a.get("content", ""), str):
            raise ValueError("artifact content must be a string")

    return obj


def request_to_json(req: dict[str, Any]) -> str:
    return json.dumps(req, indent=2, ensure_ascii=False)
