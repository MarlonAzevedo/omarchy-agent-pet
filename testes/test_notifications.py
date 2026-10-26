import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from agent_pet.hooks import handle_event


class NotificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.state = self.root / "state"
        self.config = self.root / "config.json"
        handle_event({"hook_event_name": "SessionStart", "session_id": "s1", "cwd": "/tmp/project"}, self.state, self.config, now_ms=1000)

    def tearDown(self):
        self.temp.cleanup()

    def session(self):
        digest = __import__("hashlib").sha256(b"s1").hexdigest()
        return json.loads((self.state / "sessions" / f"{digest}.json").read_text())

    def prompt(self):
        return {"hook_event_name": "Notification", "session_id": "s1", "notification_type": "permission_prompt", "message": "Claude needs your permission"}

    def test_permission_prompt_notifies_without_sensitive_input(self):
        tool = {"hook_event_name": "PreToolUse", "session_id": "s1", "tool_name": "Bash", "tool_input": {"command": "secret prompt content"}}
        handle_event(tool, self.state, self.config, now_ms=1500)
        with patch("agent_pet.hooks.subprocess.run") as run:
            self.assertEqual(handle_event(self.prompt(), self.state, self.config, now_ms=2000), 0)
        session = self.session()
        self.assertEqual((session["status"], session["attention_reason"]), ("attention", "permission"))
        args = run.call_args.args[0]
        self.assertIn("Bash", " ".join(args))
        self.assertIn("/tmp/project", args)
        self.assertNotIn("secret prompt content", " ".join(args))

    def test_claude_permission_request_waits_for_prompt(self):
        # Regressão: PermissionRequest vem antes do diálogo e notificava sem o usuário precisar agir
        event = {"hook_event_name": "PermissionRequest", "session_id": "s1", "tool_name": "Bash", "tool_input": {"command": "ls"}, "permission_mode": "default"}
        with patch("agent_pet.hooks.subprocess.run") as run:
            self.assertEqual(handle_event(event, self.state, self.config, now_ms=2000), 0)
        run.assert_not_called()
        self.assertEqual(self.session()["status"], "attention")

    def test_auto_mode_permission_request_is_ignored(self):
        # Regressão: no modo auto o classificador aprova sozinho depois do PermissionRequest
        handle_event({"hook_event_name": "PreToolUse", "session_id": "s1", "tool_name": "Bash", "tool_input": {"command": "ls"}}, self.state, self.config, now_ms=1500)
        for mode in ("auto", "bypassPermissions", "dontAsk"):
            event = {"hook_event_name": "PermissionRequest", "session_id": "s1", "tool_name": "Bash", "tool_input": {"command": "ls"}, "permission_mode": mode}
            with self.subTest(mode=mode), patch("agent_pet.hooks.subprocess.run") as run:
                self.assertEqual(handle_event(event, self.state, self.config, now_ms=2000), 0)
                run.assert_not_called()
                self.assertEqual(self.session()["status"], "working")

    def test_codex_permission_request_notifies(self):
        handle_event({"hook_event_name": "SessionStart", "session_id": "s1", "cwd": "/tmp/api"}, self.state, self.config, now_ms=1000, agent="codex")
        event = {"hook_event_name": "PermissionRequest", "session_id": "s1", "tool_name": "Bash", "tool_input": {"command": "ls"}}
        with patch("agent_pet.hooks.subprocess.run") as run:
            self.assertEqual(handle_event(event, self.state, self.config, now_ms=2000, agent="codex"), 0)
        self.assertIn("/tmp/api", run.call_args.args[0])

    def test_agent_needs_input_is_forwarded(self):
        event = {"hook_event_name": "Notification", "session_id": "s1", "notification_type": "agent_needs_input", "title": "Title", "message": "Message"}
        with patch("agent_pet.hooks.subprocess.run") as run:
            self.assertEqual(handle_event(event, self.state, self.config, now_ms=2000), 0)
        self.assertEqual(self.session()["status"], "attention")
        self.assertIn("Message", run.call_args.args[0])

    def test_idle_prompt_is_not_attention(self):
        # Regressão: idle_prompt chega 60 s depois de toda resposta, sem pergunta nenhuma
        event = {"hook_event_name": "Notification", "session_id": "s1", "notification_type": "idle_prompt", "message": "waiting"}
        with patch("agent_pet.hooks.subprocess.run") as run:
            self.assertEqual(handle_event(event, self.state, self.config, now_ms=2000), 0)
        run.assert_not_called()
        self.assertEqual(self.session()["status"], "idle")

    def test_disabled_notifications_still_update_state(self):
        self.config.write_text(json.dumps({"notifications_enabled": False}))
        event = {
            "hook_event_name": "Notification",
            "session_id": "s1",
            "notification_type": "agent_needs_input",
            "title": "Waiting",
            "message": "Input needed",
        }
        with patch("agent_pet.hooks.subprocess.run") as run:
            self.assertEqual(handle_event(event, self.state, self.config, now_ms=2000), 0)
        self.assertEqual(self.session()["status"], "attention")
        run.assert_not_called()

    def test_discreet_mode_silences_permission_prompts(self):
        self.config.write_text(json.dumps({"discreet": True}))
        with patch("agent_pet.hooks.subprocess.run") as run:
            self.assertEqual(handle_event(self.prompt(), self.state, self.config, now_ms=2000), 0)
        self.assertEqual(self.session()["status"], "attention")
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
