"""Entry point and argument parsing for the Alloy CLI."""

import argparse
import sys
from pathlib import Path

from . import compiler


def _add_common_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Path to the Alloy package directory (default: current directory)",
    )
    parser.add_argument(
        "--provider",
        help="LLM provider (ollama, openai, generic openai-compatible)",
    )
    parser.add_argument("--model", help="Model name")
    parser.add_argument("--base-url", help="OpenAI-compatible base URL")
    parser.add_argument("--api-key", help="API key for remote providers")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="alloy",
        description="Alloy v0.2 compiler CLI (LLM-as-compiler).",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    check = subparsers.add_parser("check", help="Type-check a package via ACP")
    _add_common_args(check)

    build = subparsers.add_parser("build", help="Build a package via ACP")
    _add_common_args(build)
    build.add_argument("--target", help="Target triple")
    build.add_argument(
        "--emit",
        choices=["ir", "assembly", "c", "wasm", "object"],
        help="Emit format",
    )
    build.add_argument(
        "--opt",
        type=int,
        choices=[0, 1, 2, 3],
        help="Optimization level",
    )

    run = subparsers.add_parser("run", help="Build and run a package")
    _add_common_args(run)
    run.add_argument("--target", help="Target triple")
    run.add_argument(
        "--emit",
        choices=["ir", "assembly", "c", "wasm", "object"],
        help="Emit format (default: c)",
    )
    run.add_argument(
        "--opt",
        type=int,
        choices=[0, 1, 2, 3],
        help="Optimization level",
    )

    init = subparsers.add_parser("init", help="Create a minimal Alloy package")
    init.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Directory to initialize (default: current directory)",
    )

    args = parser.parse_args(argv)
    package_dir = Path(args.path).resolve()

    if args.command == "check":
        return compiler.check(package_dir, args)
    if args.command == "build":
        return compiler.build(package_dir, args)
    if args.command == "run":
        return compiler.run(package_dir, args)
    if args.command == "init":
        return compiler.init(package_dir, args)

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
