import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from agent_pet.installer import write_settings_atomically


ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        self.settings = self.home / ".claude" / "settings.json"
        self.settings.parent.mkdir(parents=True)

    def tearDown(self):
        self.temp.cleanup()

    def run_setup(self, answer="y\n", args=("setup",)):
        env = os.environ.copy()
        env["HOME"] = str(self.home)
        env.pop("CODEX_HOME", None)
        return subprocess.run(
            [sys.executable, str(ROOT / "bin" / "agent-pet"), *args],
            input=answer,
            text=True,
            capture_output=True,
            env=env,
        )

    def test_setup_backs_up_and_merges_hooks_once(self):
        original = {
            "otherSetting": True,
            "hooks": {"Stop": [{"matcher": "*", "hooks": [{"type": "command", "command": "existing-hook"}]}]},
        }
        self.settings.write_text(json.dumps(original))
        first = self.run_setup()
        self.assertEqual(first.returncode, 0)
        backups = list(self.settings.parent.glob("settings.json.bak.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(json.loads(backups[0].read_text()), original)
        installed = json.loads(self.settings.read_text())
        self.assertTrue(installed["otherSetting"])
        self.assertEqual(installed["hooks"]["Stop"][0], original["hooks"]["Stop"][0])
        installed_bytes = self.settings.read_bytes()
        second = self.run_setup()
        self.assertEqual(second.returncode, 0)
        self.assertEqual(self.settings.read_bytes(), installed_bytes)
        installed = json.loads(self.settings.read_text())
        self.assertEqual(sum(1 for entry in installed["hooks"]["Stop"] for hook in entry["hooks"] if "pet-hook.py" in hook.get("command", "")), 1)

    def test_setup_creates_default_notification_config(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0)
        config = self.home / ".config" / "agent-pet" / "config.json"
        self.assertEqual(json.loads(config.read_text()), {"notifications_enabled": True})
        config.write_text(json.dumps({"notifications_enabled": False}))
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertFalse(json.loads(config.read_text())["notifications_enabled"])

    def test_settings_errors_preserve_original_bytes(self):
        malformed = b'{"hooks":'
        self.settings.write_bytes(malformed)
        result = self.run_setup()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.settings.read_bytes(), malformed)

        original = b'{"keep": "original"}'
        self.settings.write_bytes(original)
        with patch("agent_pet.installer.os.replace", side_effect=OSError("disk error")):
            with self.assertRaises(OSError):
                write_settings_atomically(self.settings, b'{"keep": "changed"}')
        self.assertEqual(self.settings.read_bytes(), original)

    def test_cancel_leaves_settings_unchanged(self):
        original = b'{"keep": true}'
        self.settings.write_bytes(original)
        result = self.run_setup("n\n")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.settings.read_bytes(), original)

    def test_installed_hooks_are_async_and_use_supported_events(self):
        self.settings.write_text("{}")
        result = self.run_setup()
        self.assertEqual(result.returncode, 0)
        settings = json.loads(self.settings.read_text())
        hooks = settings["hooks"]
        expected = {
            "SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse",
            "PostToolUseFailure", "Stop", "PermissionRequest", "Notification",
        }
        self.assertEqual(set(hooks), expected)
        for event_name, groups in hooks.items():
            for group in groups:
                for hook in group["hooks"]:
                    self.assertEqual(hook["type"], "command")
                    self.assertIs(hook["async"], True)
        self.assertEqual(hooks["Notification"][0]["matcher"], "agent_needs_input|permission_prompt")

    def test_setup_exit_codes(self):
        self.settings.write_text("{}")
        self.assertEqual(self.run_setup("n\n").returncode, 2)
        self.settings.write_text("{")
        self.assertEqual(self.run_setup().returncode, 1)
        self.settings.write_text("{}")
        self.assertEqual(self.run_setup().returncode, 0)


    def test_setup_installs_codex_hooks_when_codex_exists(self):
        self.settings.write_text("{}")
        codex_hooks = self.home / ".codex" / "hooks.json"
        codex_hooks.parent.mkdir()
        original = {"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "existing-hook"}]}]}}
        codex_hooks.write_text(json.dumps(original))
        self.assertEqual(self.run_setup().returncode, 0)
        hooks = json.loads(codex_hooks.read_text())["hooks"]
        self.assertEqual(
            set(hooks),
            {"SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "Interrupt"},
        )
        self.assertEqual(hooks["Stop"][0], original["hooks"]["Stop"][0])
        for groups in hooks.values():
            for group in groups:
                for hook in group["hooks"]:
                    if "pet-hook.py" in hook["command"]:
                        self.assertTrue(hook["command"].endswith("--agent codex"))
        self.assertEqual(len(list(codex_hooks.parent.glob("hooks.json.bak.*"))), 1)
        claude_commands = [hook["command"] for groups in json.loads(self.settings.read_text())["hooks"].values() for group in groups for hook in group["hooks"]]
        self.assertTrue(all("--agent" not in command for command in claude_commands))

    def test_codex_session_end_is_not_async(self):
        # Regressão: o Codex avisa "running async SessionEnd hook synchronously"
        self.settings.write_text("{}")
        codex_hooks = self.home / ".codex" / "hooks.json"
        codex_hooks.parent.mkdir()
        codex_hooks.write_text("{}")
        self.assertEqual(self.run_setup().returncode, 0)
        command = json.loads(codex_hooks.read_text())["hooks"]["SessionEnd"][0]["hooks"][0]["command"]
        # instalação antiga, com async no SessionEnd, é corrigida
        old = {"hooks": {"SessionEnd": [{"hooks": [{"type": "command", "command": command, "async": True}]}]}}
        codex_hooks.write_text(json.dumps(old))
        self.assertEqual(self.run_setup().returncode, 0)
        hooks = json.loads(codex_hooks.read_text())["hooks"]
        self.assertEqual(len(hooks["SessionEnd"][0]["hooks"]), 1)
        self.assertNotIn("async", hooks["SessionEnd"][0]["hooks"][0])
        self.assertIs(hooks["Stop"][0]["hooks"][0]["async"], True)
        claude = json.loads(self.settings.read_text())["hooks"]
        self.assertIs(claude["SessionEnd"][0]["hooks"][0]["async"], True)

    def test_setup_skips_codex_when_not_installed(self):
        self.settings.write_text("{}")
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertFalse((self.home / ".codex").exists())

    def test_panel_checks_and_installs_without_prompt(self):
        # O painel pergunta com o botão; setup --yes não lê o terminal
        self.settings.write_text("{}")
        self.assertEqual(self.run_setup(args=("check",)).returncode, 3)
        self.assertEqual(self.run_setup(answer="", args=("setup", "--yes")).returncode, 0)
        self.assertIn("SessionStart", json.loads(self.settings.read_text())["hooks"])
        self.assertEqual(self.run_setup(args=("check",)).returncode, 0)
        self.assertEqual(len(list(self.settings.parent.glob("settings.json.bak.*"))), 1)

    def test_check_does_not_write(self):
        self.settings.write_text("{}")
        self.run_setup(args=("check",))
        self.assertEqual(self.settings.read_text(), "{}")
        self.assertFalse((self.home / ".config" / "agent-pet").exists())

    def test_setup_removes_old_antigravity_block(self):
        # Regressão: o bloco da 0.4.0 sem tratamento do agy barra as ferramentas dele
        self.settings.write_text("{}")
        agy_hooks = self.home / ".gemini" / "config" / "hooks.json"
        agy_hooks.parent.mkdir(parents=True)
        agy_hooks.write_text(json.dumps({"retro-agent-pet": {"Stop": []}, "outro": {"Stop": []}}))
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(json.loads(agy_hooks.read_text()), {"outro": {"Stop": []}})
        self.assertEqual(len(list(agy_hooks.parent.glob("hooks.json.bak.*"))), 1)


    def test_setup_replaces_hooks_from_old_location(self):
        stale = "/usr/bin/python3 /old/place/hook/pet-hook.py"
        original = {"hooks": {
            "Stop": [{"hooks": [{"type": "command", "command": stale, "async": True}, {"type": "command", "command": "existing-hook"}]}],
            "SessionStart": [{"hooks": [{"type": "command", "command": stale, "async": True}]}],
        }}
        self.settings.write_text(json.dumps(original))
        self.assertEqual(self.run_setup().returncode, 0)
        hooks = json.loads(self.settings.read_text())["hooks"]
        commands = [hook["command"] for groups in hooks.values() for group in groups for hook in group["hooks"]]
        self.assertNotIn(stale, commands)
        self.assertIn("existing-hook", commands)
        self.assertEqual(sum(1 for command in commands if "pet-hook.py" in command), len(hooks))


if __name__ == "__main__":
    unittest.main()
