import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class CliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / "config" / "agent-pet" / "config.json"
        self.state = self.home / "state" / "agent-pet"
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / "config"),
                        XDG_STATE_HOME=str(self.home / "state"))

    def cli(self, *args):
        return subprocess.run([sys.executable, str(ROOT / "bin" / "agent-pet"), *args],
                              env=self.env, text=True, capture_output=True)

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding="utf-8")

    def result(self, *args):
        result = self.cli(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_help_and_invalid_commands_do_not_write_state(self):
        self.assertEqual(self.cli("--help").returncode, 0)
        self.assertNotEqual(self.cli("unknown").returncode, 0)
        self.assertNotEqual(self.cli("status", "extra").returncode, 0)
        self.assertFalse(self.config.exists())
        self.assertFalse(self.state.exists())

    def test_empty_status_is_read_only(self):
        status = self.result("status", "--json")
        self.assertEqual(status["sessions"], [])
        self.assertEqual(status["character"], "computer")
        self.assertIsNone(status["focus"])
        self.assertEqual(status["usage"], [])
        self.assertIn("Nenhuma sessão", self.cli("status").stdout)
        self.assertFalse(self.state.exists())
        self.assertFalse(self.config.exists())

    def test_status_filters_sorts_and_ignores_broken_records(self):
        self.write(self.config, {"hidden_agents": ["codex"], "character": "dog"})
        for name, data in {
            "idle": {"session_id": "idle", "status": "idle", "cwd": "/project/quiet", "updated_at": 50},
            "attention": {"session_id": "attention", "status": "attention", "session_title": "Needs answer", "updated_at": 10},
            "hidden": {"session_id": "hidden", "agent": "codex", "status": "working", "updated_at": 60},
            "invalid": [1, 2],
        }.items():
            self.write(self.state / "sessions" / f"{name}.json", data)
        (self.state / "sessions" / "broken.json").write_text("{", encoding="utf-8")
        (self.state / "sessions" / "binary.json").write_bytes(b"\xff")
        usage = self.home / "state" / "omarchy" / "agents" / "usage"
        self.write(usage / "claude.json", {"id": "claude", "limits": [{"label": "5h", "percent": 0.5}]})
        self.write(usage / "codex.json", {"id": "codex", "limits": []})
        status = self.result("status", "--json")
        self.assertEqual([s["session_id"] for s in status["sessions"]], ["attention", "idle"])
        self.assertEqual(status["character"], "dog")
        self.assertEqual([u["id"] for u in status["usage"]], ["claude"])
        self.assertIn("50%", self.cli("status").stdout)
        self.assertIn("Needs answer", self.cli("status").stdout)

    def test_character_selection_preserves_preferences(self):
        self.write(self.config, {"discreet": True, "hidden_agents": ["codex"], "language": "en"})
        for character in ["computer", "cat", "robot", "dog"]:
            result = self.cli("pet", character)
            self.assertEqual(result.returncode, 0, result.stderr)
            config = json.loads(self.config.read_text())
            self.assertEqual(config["character"], character)
            self.assertTrue(config["discreet"])
            self.assertEqual(config["hidden_agents"], ["codex"])
            self.assertEqual(config["language"], "en")
        before = self.config.read_bytes()
        self.assertNotEqual(self.cli("pet", "wolf").returncode, 0)
        self.assertEqual(self.config.read_bytes(), before)
        self.assertIn("dog", self.cli("pet").stdout)

    def test_expired_limit_is_zero_like_panel(self):
        usage = self.home / "state" / "omarchy" / "agents" / "usage"
        self.write(usage / "claude.json", {"id": "claude", "limits": [
            {"label": "5h", "percent": 0.98, "resetsAt": "2000-01-01T00:00:00Z"},
            {"label": "7d", "percent": 0.41, "resetsAt": "2999-01-01T00:00:00Z"},
        ]})
        result = self.cli("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("5h · 0%", result.stdout)
        self.assertIn("7d · 41%", result.stdout)
        self.assertEqual(self.result("status", "--json")["usage"][0]["limits"][0]["percent"], 0.98)

    def test_corrupt_config_is_not_overwritten(self):
        for content in [b"{", b"[]", b"\xff"]:
            self.config.parent.mkdir(parents=True, exist_ok=True)
            self.config.write_bytes(content)
            result = self.cli("pet", "cat")
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("Traceback", result.stderr)
            self.assertEqual(self.config.read_bytes(), content)

    def test_focus_start_pause_resume_stop(self):
        result = self.cli("focus", "25", "5", "4")
        self.assertEqual(result.returncode, 0, result.stderr)
        path = self.state / "focus.json"
        focus = json.loads(path.read_text())
        self.assertEqual([focus[k] for k in ["work_min", "break_min", "rounds"]], [25, 5, 4])
        self.assertIsInstance(focus["started_at"], int)
        self.assertIsNone(focus["paused_at"])
        self.assertEqual(self.result("status", "--json")["focus"]["phase"], "work")
        self.assertEqual(self.cli("focus", "pause").returncode, 0)
        paused = json.loads(path.read_text())
        self.assertIsInstance(paused["paused_at"], int)
        self.assertTrue(self.result("status", "--json")["focus"]["paused"])
        self.assertEqual(self.cli("focus", "pause").returncode, 0)
        self.assertEqual(json.loads(path.read_text()), paused)
        self.assertEqual(self.cli("focus", "resume").returncode, 0)
        resumed = json.loads(path.read_text())
        self.assertIsNone(resumed["paused_at"])
        self.assertGreaterEqual(resumed["started_at"], focus["started_at"])
        self.assertEqual(self.cli("focus", "stop").returncode, 0)
        self.assertEqual(json.loads(path.read_text()), {})
        self.assertIsNone(self.result("status", "--json")["focus"])

    def test_invalid_focus_arguments_preserve_running_timer(self):
        self.write(self.state / "focus.json", {"work_min": 25, "break_min": 5, "rounds": 4, "started_at": 0})
        before = (self.state / "focus.json").read_bytes()
        for args in [("0", "5", "4"), ("25", "-1", "4"), ("25", "5", "0"),
                     ("25", "5"), ("1.5", "5", "4"), ("25", "5", "4", "extra"), ("oops",)]:
            result = self.cli("focus", *args)
            self.assertNotEqual(result.returncode, 0, args)
            self.assertEqual((self.state / "focus.json").read_bytes(), before)

    def test_focus_without_timer_and_zero_break(self):
        self.assertEqual(self.cli("focus").returncode, 0)
        self.assertFalse(self.state.exists())
        self.assertNotEqual(self.cli("focus", "pause").returncode, 0)
        self.assertNotEqual(self.cli("focus", "resume").returncode, 0)
        self.assertEqual(self.cli("focus", "1", "0", "2").returncode, 0)

    def test_invalid_focus_state_does_not_crash_or_get_overwritten(self):
        path = self.state / "focus.json"
        for data in [{"started_at": "invalid"}, {"started_at": 0, "work_min": 0, "break_min": 5, "rounds": 2}]:
            self.write(path, data)
            before = path.read_bytes()
            result = self.cli("focus", "pause")
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("Traceback", result.stderr)
            self.assertEqual(path.read_bytes(), before)

    def test_entrypoint_works_through_symlink(self):
        link = self.home / "agent-pet"
        link.symlink_to(ROOT / "bin" / "agent-pet")
        result = subprocess.run([str(link), "status", "--json"], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["character"], "computer")

    def test_home_fallback_when_xdg_empty(self):
        self.env["XDG_CONFIG_HOME"] = ""
        self.env["XDG_STATE_HOME"] = ""
        self.assertEqual(self.cli("pet", "cat").returncode, 0)
        self.assertTrue((self.home / ".config" / "agent-pet" / "config.json").exists())
        self.assertEqual(self.cli("focus", "25", "5", "4").returncode, 0)
        self.assertTrue((self.home / ".local" / "state" / "agent-pet" / "focus.json").exists())

    def test_focus_calculation_matches_panel_at_boundaries(self):
        from agent_pet.cli import focus_info

        timer = {"work_min": 25, "break_min": 5, "rounds": 2, "started_at": 0, "paused_at": None}
        cases = [{"focus": timer, "now": ms} for ms in [-1, 0, 1, 1499999, 1500000, 1799999, 1800000, 3299999, 3300000]]
        cases += [{"focus": dict(timer, paused_at=600000), "now": 1200000},
                  {"focus": dict(timer, break_min=0), "now": 1500000}, {"focus": {}, "now": 0}]
        script = 'const fs = require("node:fs"); const source = fs.readFileSync("Model.js", "utf8").replace(/^\\.pragma library\\s*/, ""); const fn = new Function(source + "; return focusPhase")(); const cases = JSON.parse(fs.readFileSync(0, "utf8")); process.stdout.write(JSON.stringify(cases.map(c => fn(c.focus, c.now))));'
        result = subprocess.run(["node", "-e", script], input=json.dumps(cases), text=True, capture_output=True, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = json.loads(result.stdout)
        for case, want in zip(cases, expected):
            self.assertEqual(focus_info(case["focus"], case["now"]), want, case)
