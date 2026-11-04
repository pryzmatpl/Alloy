"""Integration tests for the Alloy CLI using a mock LLM provider."""

import argparse
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alloy_cli import compiler, providers


class MockArgs:
    """Minimal Namespace-like object for CLI overrides."""

    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)

    def __getattr__(self, name):
        return None


def _default_args(**overrides):
    defaults = {
        "provider": None,
        "model": None,
        "base_url": None,
        "api_key": None,
        "target": None,
        "emit": None,
        "opt": None,
    }
    defaults.update(overrides)
    return MockArgs(**defaults)


class TestCliMock(unittest.TestCase):
    def _make_pkg(self) -> Path:
        d = Path(tempfile.mkdtemp())
        (d / "src").mkdir()
        (d / "alloy.toml").write_text(
            '[package]\nname = "hello"\nversion = "0.2.0"\nkind = "bin"\n',
            encoding="utf-8",
        )
        (d / "src" / "main.al").write_text(
            'function main(): i32 {\n    return 0;\n}\n',
            encoding="utf-8",
        )
        return d

    def _mock_response(self) -> str:
        return json.dumps(
            {
                "protocol": "acp/0.2",
                "status": "ok",
                "diagnostics": [],
                "resolved_target": "x86_64-unknown-linux-gnu",
                "ir": "@function main() -> i32 {\nentry:\n  ret 0\n}",
                "artifacts": [
                    {
                        "name": "hello.c",
                        "content": "#include <stdio.h>\nint main(void) { puts(\"hi\"); return 0; }\n",
                        "encoding": "text",
                    }
                ],
                "notes": "mock",
            }
        )

    @patch.object(providers, "chat_completion", return_value=None)
    def test_check(self, mock_cc):
        mock_cc.return_value = json.dumps(
            {"protocol": "acp/0.2", "status": "ok", "diagnostics": []}
        )
        d = self._make_pkg()
        args = _default_args()
        rc = compiler.check(d, args)
        self.assertEqual(rc, 0)
        mock_cc.assert_called_once()

    @patch.object(providers, "chat_completion", return_value=None)
    def test_build_writes_artifacts(self, mock_cc):
        mock_cc.return_value = self._mock_response()
        d = self._make_pkg()
        args = _default_args()
        rc = compiler.build(d, args)
        self.assertEqual(rc, 0)
        out = d / "target" / "x86_64_unknown_linux_gnu"
        self.assertTrue((out / "hello.c").exists())
        self.assertTrue((out / "hello.alir").exists())
        self.assertTrue((out / "hello").exists())

    @patch.object(providers, "chat_completion", return_value=None)
    def test_build_error_status(self, mock_cc):
        mock_cc.return_value = json.dumps(
            {
                "protocol": "acp/0.2",
                "status": "error",
                "diagnostics": [{"level": "error", "message": "bad syntax"}],
            }
        )
        d = self._make_pkg()
        args = _default_args()
        rc = compiler.build(d, args)
        self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
