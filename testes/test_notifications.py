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

    def test_permission_request_notifies_without_sensitive_input(self):
        event = {
            "hook_event_name": "PermissionRequest",
            "session_id": "s1",
            "tool_name": "Bash",
            "tool_input": {"command": "secret prompt content"},
            "last_assistant_message": "secret assistant content",
        }
        with patch("agent_pet.hooks.subprocess.run") as run:
            self.assertEqual(handle_event(event, self.state, self.config, now_ms=2000), 0)
        self.assertEqual(self.session()["status"], "attention")
        args = run.call_args.args[0]
        self.assertIn("Bash", " ".join(args))
        self.assertIn("/tmp/project", args)
        self.assertNotIn("secret prompt content", args)
        self.assertNotIn("secret assistant content", args)

    def test_attention_notification_types_are_forwarded(self):
        for kind in ("idle_prompt", "agent_needs_input"):
            with self.subTest(kind=kind), patch("agent_pet.hooks.subprocess.run") as run:
                event = {
                    "hook_event_name": "Notification",
                    "session_id": "s1",
                    "notification_type": kind,
                    "title": f"Title {kind}",
                    "message": f"Message {kind}",
                }
                self.assertEqual(handle_event(event, self.state, self.config, now_ms=2000), 0)
                self.assertEqual(self.session()["status"], "attention")
                self.assertIn(f"Title {kind}", run.call_args.args[0])
                self.assertIn(f"Message {kind}", run.call_args.args[0])

    def test_permission_prompt_is_not_duplicated(self):
        event = {
            "hook_event_name": "Notification",
            "session_id": "s1",
            "notification_type": "permission_prompt",
            "message": "permission needed",
        }
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


if __name__ == "__main__":
    unittest.main()
