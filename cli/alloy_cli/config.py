"""Configuration loading for the Alloy CLI."""

import os
import platform
import tomllib
from pathlib import Path
from typing import Any


DEFAULTS: dict[str, Any] = {
    "compiler": {
        "protocol": "acp/0.2",
        "provider": "ollama",
        "model": "qwen2.5-coder:7b",
        "base_url": "http://localhost:11434/v1",
        "api_key": "",
    }
}


def _host_triple() -> str:
    """Best-effort default host target triple."""
    machine = platform.machine().lower()
    system = platform.system().lower()
    if system == "linux":
        return f"{machine}-unknown-linux-gnu"
    if system == "darwin":
        return f"{machine}-apple-darwin"
    if system == "windows":
        return "x86_64-pc-windows-msvc"
    return "x86_64-unknown-linux-gnu"


def load_config(package_dir: Path) -> dict[str, Any]:
    """Load alloy.toml and merge with environment defaults."""
    config: dict[str, Any] = {
        "target": _host_triple(),
        "emit": "c",
        "opt_level": 0,
    }
    config.update(DEFAULTS)

    manifest = package_dir / "alloy.toml"
    if manifest.exists():
        with manifest.open("rb") as f:
            data = tomllib.load(f)
        for section in ("package", "compiler"):
            if section in data:
                config.setdefault(section, {}).update(data[section])
        # top-level compiler keys are also allowed for convenience
        for key in ("provider", "model", "base_url", "api_key", "protocol"):
            if key in data:
                config.setdefault("compiler", {})[key] = data[key]
        for key in ("target", "emit", "opt_level"):
            if key in data:
                config[key] = data[key]

    # Environment overrides
    if env_provider := os.environ.get("ALLOY_PROVIDER"):
        config.setdefault("compiler", {})["provider"] = env_provider
    if env_model := os.environ.get("ALLOY_MODEL"):
        config.setdefault("compiler", {})["model"] = env_model
    if env_key := os.environ.get("ALLOY_API_KEY"):
        config.setdefault("compiler", {})["api_key"] = env_key
    if env_url := os.environ.get("ALLOY_BASE_URL"):
        config.setdefault("compiler", {})["base_url"] = env_url

    return config


def apply_cli_overrides(config: dict[str, Any], args: Any) -> dict[str, Any]:
    """Apply command-line flag overrides onto the config dict."""
    if getattr(args, "target", None):
        config["target"] = args.target
    if getattr(args, "emit", None):
        config["emit"] = args.emit
    if getattr(args, "opt", None) is not None:
        config["opt_level"] = args.opt
    if getattr(args, "provider", None):
        config.setdefault("compiler", {})["provider"] = args.provider
    if getattr(args, "model", None):
        config.setdefault("compiler", {})["model"] = args.model
    if getattr(args, "base_url", None):
        config.setdefault("compiler", {})["base_url"] = args.base_url
    if getattr(args, "api_key", None):
        config.setdefault("compiler", {})["api_key"] = args.api_key
    return config
