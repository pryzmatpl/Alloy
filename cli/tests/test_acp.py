"""Unit tests for the ACP helpers."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alloy_cli import acp


class TestAcp(unittest.TestCase):
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

    def test_collect_package(self):
        d = self._make_pkg()
        pkg = acp.collect_package(d)
        self.assertEqual(pkg["name"], "hello")
        self.assertEqual(pkg["kind"], "bin")
        self.assertIn("alloy.toml", pkg["files"])
        self.assertIn("src/main.al", pkg["files"])

    def test_build_request(self):
        d = self._make_pkg()
        req = acp.build_request(d, "x86_64-unknown-linux-gnu", ["typecheck"], emit="c", opt_level=0)
        self.assertEqual(req["protocol"], "acp/0.2")
        self.assertEqual(req["target"], "x86_64-unknown-linux-gnu")
        self.assertEqual(req["passes"], ["typecheck"])
        self.assertEqual(req["options"], {"opt_level": 0, "emit": "c"})

    def test_validate_response_ok(self):
        resp = {
            "protocol": "acp/0.2",
            "status": "ok",
            "diagnostics": [],
            "artifacts": [{"name": "hello.c", "content": "int main(void){return 0;}"}],
        }
        self.assertEqual(acp.validate_response(resp), resp)

    def test_validate_response_error(self):
        resp = {
            "protocol": "acp/0.2",
            "status": "error",
            "diagnostics": [{"level": "error", "message": "boom"}],
        }
        self.assertEqual(acp.validate_response(resp), resp)

    def test_validate_response_bad_protocol(self):
        with self.assertRaises(ValueError):
            acp.validate_response({"protocol": "acp/0.1", "status": "ok"})

    def test_request_to_json_roundtrip(self):
        d = self._make_pkg()
        req = acp.build_request(d, "x86_64-unknown-linux-gnu", ["typecheck"])
        s = acp.request_to_json(req)
        parsed = json.loads(s)
        self.assertEqual(parsed["protocol"], "acp/0.2")


if __name__ == "__main__":
    unittest.main()
