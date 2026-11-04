"""Optional end-to-end test against a real local model."""

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alloy_cli import compiler, providers


class TestIntegration(unittest.TestCase):
    def _make_pkg(self) -> Path:
        d = Path(tempfile.mkdtemp())
        (d / "src").mkdir()
        (d / "alloy.toml").write_text(
            '[package]\nname = "hello"\nversion = "0.2.0"\nkind = "bin"\n\n[compiler]\nprovider = "ollama"\nmodel = "qwen2.5:0.5b"\nbase_url = "http://localhost:11434/v1"\n',
            encoding="utf-8",
        )
        (d / "src" / "main.al").write_text(
            'use std.io.{Writer, write_str, register_io};\nuse std.di.Container;\n\nfunction main(): i32 {\n    let di = Container();\n    register_io(di);\n    let out: Writer = di.get<Writer>();\n    match write_str(out, "Hello, world!\\n") {\n        Ok(_)  => { return 0; }\n        Err(_) => { return 1; }\n    }\n}\n',
            encoding="utf-8",
        )
        return d

    def setUp(self):
        self.model = os.environ.get("OLLAMA_TEST_MODEL", "qwen2.5:0.5b")
        self.base_url = os.environ.get("ALLOY_BASE_URL", "http://localhost:11434/v1")

    def test_ollama_check(self):
        """Skip if Ollama is not reachable."""
        try:
            providers.chat_completion(
                base_url=self.base_url,
                api_key="",
                model=self.model,
                messages=[{"role": "user", "content": "say hi"}],
                timeout=10,
            )
        except Exception as exc:
            self.skipTest(f"Local model not reachable: {exc}")

        d = self._make_pkg()
        args = type("Args", (), {
            "provider": None,
            "model": None,
            "base_url": None,
            "api_key": None,
            "target": None,
            "emit": None,
            "opt": None,
        })()
        rc = compiler.check(d, args)
        self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
