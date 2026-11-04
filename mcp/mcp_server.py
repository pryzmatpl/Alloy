#!/usr/bin/env python3
"""Minimal Alloy v0.2 MCP server over stdio JSON-RPC.

Exposes three tools:
  - alloy_check
  - alloy_compile
  - alloy_emit

Each tool accepts an ACP-style package description and talks to the configured
LLM through an OpenAI-compatible endpoint.
"""

import json
import os
import sys
from pathlib import Path

# Make the CLI package importable from this directory.
_CLI = Path(__file__).resolve().parents[1] / "cli"
sys.path.insert(0, str(_CLI))

from alloy_cli import acp, providers


def _system_prompt() -> str:
    path = Path(__file__).resolve().parents[1] / "COMPILER_SYSTEM.md"
    if path.exists():
        return path.read_text(encoding="utf-8")
    return "You are the Alloy v0.2 compiler. Return only JSON ACP responses."


def _provider_cfg(args: dict) -> dict:
    return {
        "provider": args.get("provider") or os.environ.get("ALLOY_PROVIDER", "ollama"),
        "model": args.get("model") or os.environ.get("ALLOY_MODEL", "qwen2.5-coder:7b"),
        "base_url": args.get("base_url") or os.environ.get("ALLOY_BASE_URL", "http://localhost:11434/v1"),
        "api_key": args.get("api_key") or os.environ.get("ALLOY_API_KEY", ""),
    }


def _run_passes(args: dict, passes: list[str]) -> dict:
    package = args["package"]
    target = args.get("target", "x86_64-unknown-linux-gnu")
    emit = args.get("emit", "c")
    opt_level = args.get("opt_level", 0)

    req = {
        "protocol": acp.PROTOCOL,
        "package": package,
        "target": target,
        "passes": passes,
        "options": {"opt_level": opt_level, "emit": emit},
    }
    cfg = _provider_cfg(args)

    try:
        content = providers.chat_completion(
            base_url=cfg["base_url"],
            api_key=cfg["api_key"],
            model=cfg["model"],
            messages=[
                {"role": "system", "content": _system_prompt()},
                {"role": "user", "content": acp.request_to_json(req)},
            ],
            temperature=0.0,
        )
        resp = providers.extract_json(content)
        acp.validate_response(resp)
        return {"content": [{"type": "text", "text": json.dumps(resp, indent=2)}]}
    except Exception as exc:
        return {
            "content": [
                {"type": "text", "text": json.dumps({"status": "error", "message": str(exc)})}
            ],
            "isError": True,
        }


TOOLS = {
    "alloy_check": lambda args: _run_passes(args, ["typecheck"]),
    "alloy_compile": lambda args: _run_passes(args, ["typecheck", "lower", "emit"]),
    "alloy_emit": lambda args: _run_passes(args, ["lower", "emit"]),
}


def _handle(request: dict) -> dict:
    method = request.get("method")
    req_id = request.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "alloy-mcp", "version": "0.2.0"},
            },
        }

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "tools": [
                    {
                        "name": "alloy_check",
                        "description": "Type-check an Alloy v0.2 package via ACP.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "package": {
                                    "type": "object",
                                    "description": "ACP package with name, kind, and files.",
                                },
                                "target": {"type": "string"},
                                "provider": {"type": "string"},
                                "model": {"type": "string"},
                                "base_url": {"type": "string"},
                                "api_key": {"type": "string"},
                            },
                            "required": ["package"],
                        },
                    },
                    {
                        "name": "alloy_compile",
                        "description": "Compile an Alloy v0.2 package via ACP.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "package": {
                                    "type": "object",
                                    "description": "ACP package with name, kind, and files.",
                                },
                                "target": {"type": "string"},
                                "emit": {"type": "string"},
                                "opt_level": {"type": "integer"},
                                "provider": {"type": "string"},
                                "model": {"type": "string"},
                                "base_url": {"type": "string"},
                                "api_key": {"type": "string"},
                            },
                            "required": ["package"],
                        },
                    },
                    {
                        "name": "alloy_emit",
                        "description": "Emit artifacts for an Alloy v0.2 package via ACP.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "package": {
                                    "type": "object",
                                    "description": "ACP package with name, kind, and files.",
                                },
                                "target": {"type": "string"},
                                "emit": {"type": "string"},
                                "opt_level": {"type": "integer"},
                                "provider": {"type": "string"},
                                "model": {"type": "string"},
                                "base_url": {"type": "string"},
                                "api_key": {"type": "string"},
                            },
                            "required": ["package"],
                        },
                    },
                ]
            },
        }

    if method == "tools/call":
        params = request.get("params", {})
        name = params.get("name")
        args = params.get("arguments", {})
        if name not in TOOLS:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": f"Unknown tool: {name}"},
            }
        result = TOOLS[name](args)
        return {"jsonrpc": "2.0", "id": req_id, "result": result}

    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": -32601, "message": f"Method not found: {method}"},
    }


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError as exc:
            response = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": f"Parse error: {exc}"},
            }
        else:
            response = _handle(request)
        print(json.dumps(response), flush=True)


if __name__ == "__main__":
    main()
