import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from contextlib import redirect_stdout
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

from agent_pet.hooks import handle_event, main


ROOT = Path(__file__).resolve().parents[1]


class HookStateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.state = self.root / "state"
        self.config = self.root / "config.json"

    def tearDown(self):
        self.temp.cleanup()

    def send(self, event, now_ms=1700000000000):
        return handle_event(event, self.state, self.config, now_ms=now_ms)

    def session_file(self, session_id):
        digest = hashlib.sha256(session_id.encode()).hexdigest()
        return self.state / "sessions" / f"{digest}.json"

    def read_session(self, session_id):
        return json.loads(self.session_file(session_id).read_text())

    def test_session_start_creates_hashed_state(self):
        event = {
            "hook_event_name": "SessionStart",
            "session_id": "../session-one",
            "cwd": "/tmp/work",
            "session_title": "work",
        }
        self.assertEqual(self.send(event), 0)
        path = self.session_file(event["session_id"])
        self.assertTrue(path.is_file())
        self.assertEqual(path.parent, self.state / "sessions")
        data = json.loads(path.read_text())
        self.assertEqual(data["session_id"], event["session_id"])
        self.assertEqual(data["status"], "idle")

    def test_user_prompt_starts_turn(self):
        self.send({"hook_event_name": "SessionStart", "session_id": "s1"}, 1000)
        self.send({"hook_event_name": "UserPromptSubmit", "session_id": "s1"}, 2000)
        data = self.read_session("s1")
        self.assertEqual(data["status"], "working")
        self.assertEqual(data["turn_started_at"], 2000)
        self.assertIsNone(data["current_tool"])

    def test_pre_tool_use_sets_current_tool(self):
        self.send({"hook_event_name": "SessionStart", "session_id": "s1"}, 1000)
        self.send(
            {
                "hook_event_name": "PreToolUse",
                "session_id": "s1",
                "tool_name": "Bash",
            },
            2000,
        )
        data = self.read_session("s1")
        self.assertEqual(data["status"], "working")
        self.assertEqual(data["current_tool"], "Bash")
        self.assertEqual(data["activity_started_at"], 2000)

    def test_post_tool_events_clear_activity(self):
        for event_name in ("PostToolUse", "PostToolUseFailure"):
            with self.subTest(event_name=event_name):
                self.send({"hook_event_name": "SessionStart", "session_id": "s1"}, 1000)
                self.send({"hook_event_name": "UserPromptSubmit", "session_id": "s1"}, 1500)
                self.send(
                    {"hook_event_name": "PreToolUse", "session_id": "s1", "tool_name": "Bash"},
                    2000,
                )
                self.send({"hook_event_name": event_name, "session_id": "s1"}, 3000)
                data = self.read_session("s1")
                self.assertEqual(data["status"], "working")
                self.assertIsNone(data["current_tool"])
                self.assertIsNone(data["activity_started_at"])

    def test_stop_updates_daily_summary(self):
        start = 1700000000000
        self.send({"hook_event_name": "SessionStart", "session_id": "s1"}, start)
        self.send({"hook_event_name": "UserPromptSubmit", "session_id": "s1"}, start + 1000)
        self.send({"hook_event_name": "PreToolUse", "session_id": "s1", "tool_name": "Bash"}, start + 2000)
        self.send({"hook_event_name": "Stop", "session_id": "s1"}, start + 5500)
        data = self.read_session("s1")
        day = datetime.fromtimestamp((start + 5500) / 1000).date().isoformat()
        daily = json.loads((self.state / "day" / f"{day}.json").read_text())
        self.assertEqual(data["status"], "idle")
        self.assertIsNone(data["current_tool"])
        self.assertIsNone(data["activity_started_at"])
        self.assertIsNone(data["turn_started_at"])
        self.assertEqual(daily["completed_responses"], 1)
        self.assertEqual(daily["active_seconds"], 4)

    def test_session_end_removes_only_target(self):
        self.send({"hook_event_name": "SessionStart", "session_id": "s1"})
        self.send({"hook_event_name": "SessionStart", "session_id": "s2"})
        day_file = self.state / "day" / "2023-11-14.json"
        day_file.parent.mkdir(parents=True, exist_ok=True)
        day_file.write_text(json.dumps({"date": "2023-11-14", "completed_responses": 1, "active_seconds": 2}))
        self.send({"hook_event_name": "SessionEnd", "session_id": "s1"})
        self.assertFalse(self.session_file("s1").exists())
        self.assertTrue(self.session_file("s2").exists())
        self.assertTrue(day_file.exists())

    def tool(self, tool_name, tool_input, event="PreToolUse", now_ms=2000):
        self.send({"hook_event_name": "SessionStart", "session_id": "s1"}, 1000)
        self.send(
            {"hook_event_name": event, "session_id": "s1", "tool_name": tool_name, "tool_input": tool_input},
            now_ms,
        )
        return self.read_session("s1")

    def test_tool_detail_keeps_first_line_of_short_command(self):
        data = self.tool("Bash", {"command": "npm test\necho segredo"})
        self.assertEqual(data["tool_detail"], "npm test")

    def test_tool_detail_truncates_long_command(self):
        data = self.tool("Bash", {"command": "x" * 100})
        self.assertEqual(data["tool_detail"], "x" * 59 + "…")

    def test_tool_detail_uses_file_basename(self):
        data = self.tool("Edit", {"file_path": "/home/u/app/src/Hero.tsx", "old_string": "a"})
        self.assertEqual(data["tool_detail"], "Hero.tsx")

    def test_tool_detail_uses_search_pattern(self):
        self.assertEqual(self.tool("Grep", {"pattern": "TODO", "path": "/x"})["tool_detail"], "TODO")

    def test_tool_detail_ignores_unknown_input(self):
        self.assertIsNone(self.tool("Mystery", {"anything": "secret"})["tool_detail"])

    def test_permission_request_records_reason_and_detail(self):
        data = self.tool("Bash", {"command": "npm run migrate"}, event="PermissionRequest", now_ms=5000)
        self.assertEqual(data["status"], "attention")
        self.assertEqual(data["attention_reason"], "permission")
        self.assertEqual(data["current_tool"], "Bash")
        self.assertEqual(data["tool_detail"], "npm run migrate")
        self.assertEqual(data["activity_started_at"], 5000)

    def test_input_notification_records_reason(self):
        self.send({"hook_event_name": "SessionStart", "session_id": "s1"}, 1000)
        self.send({"hook_event_name": "Notification", "session_id": "s1", "notification_type": "agent_needs_input"}, 3000)
        data = self.read_session("s1")
        self.assertEqual(data["attention_reason"], "input")
        self.assertEqual(data["activity_started_at"], 3000)

    def test_post_tool_use_clears_detail_and_reason(self):
        self.tool("Bash", {"command": "npm run migrate"}, event="PermissionRequest")
        self.send({"hook_event_name": "PostToolUse", "session_id": "s1", "tool_name": "Bash"}, 6000)
        data = self.read_session("s1")
        self.assertIsNone(data["tool_detail"])
        self.assertIsNone(data["attention_reason"])

    def test_session_file_is_private(self):
        self.tool("Bash", {"command": "npm test"})
        self.assertEqual(self.session_file("s1").stat().st_mode & 0o777, 0o600)

    def test_claude_is_default_agent(self):
        self.send({"hook_event_name": "SessionStart", "session_id": "s1"}, 1000)
        self.assertEqual(self.read_session("s1")["agent"], "claude")

    def test_codex_sessions_are_namespaced(self):
        handle_event({"hook_event_name": "SessionStart", "session_id": "s1", "cwd": "/x/api"}, self.state, self.config, now_ms=1000, agent="codex")
        handle_event({"hook_event_name": "PreToolUse", "session_id": "s1", "tool_name": "Bash", "tool_input": {"command": "cargo test"}}, self.state, self.config, now_ms=2000, agent="codex")
        self.assertFalse(self.session_file("s1").exists())
        data = self.read_session("codex:s1")
        self.assertEqual(data["agent"], "codex")
        self.assertEqual(data["session_id"], "s1")
        self.assertEqual(data["tool_detail"], "cargo test")

    def test_apply_patch_detail_is_patched_file(self):
        patch_text = "*** Begin Patch\n*** Update File: src/components/Hero.tsx\n@@\n-a\n+b\n*** End Patch"
        self.assertEqual(self.tool("apply_patch", {"command": patch_text})["tool_detail"], "Hero.tsx")

    def test_interrupt_returns_to_idle(self):
        self.tool("Bash", {"command": "npm test"})
        self.send({"hook_event_name": "Interrupt", "session_id": "s1"}, 3000)
        data = self.read_session("s1")
        self.assertEqual(data["status"], "idle")
        self.assertIsNone(data["current_tool"])
        self.assertIsNone(data["tool_detail"])

    def test_main_reads_agent_argument(self):
        event = {"hook_event_name": "SessionStart", "session_id": "s9"}
        with patch("sys.stdin", io.StringIO(json.dumps(event))), patch("agent_pet.hooks.handle_event", return_value=0) as handler:
            self.assertEqual(main(["--agent", "codex"]), 0)
        self.assertEqual(handler.call_args.kwargs["agent"], "codex")

    def test_main_rejects_unknown_agent(self):
        event = {"hook_event_name": "SessionStart", "session_id": "s9"}
        with patch("sys.stdin", io.StringIO(json.dumps(event))), patch("agent_pet.hooks.handle_event", return_value=0) as handler:
            main(["--agent", "../../etc"])
        self.assertEqual(handler.call_args.kwargs["agent"], "claude")

    def agy(self, event_name, payload, pid=4242):
        payload = {"conversationId": "c1", "workspacePaths": ["/x/site"], **payload}
        out = io.StringIO()
        with patch("sys.stdin", io.StringIO(json.dumps(payload))), patch("agent_pet.hooks._agent_pid", return_value=pid), \
                patch("agent_pet.hooks._watch_end") as watch, patch("agent_pet.hooks._state_root", return_value=self.state), \
                patch("agent_pet.hooks._config_path", return_value=self.config), redirect_stdout(out):
            self.assertEqual(main(["--agent", "antigravity", "--event", event_name]), 0)
        self.assertEqual(json.loads(out.getvalue()), {})
        return watch

    def test_antigravity_turn_follows_hooks(self):
        watch = self.agy("SessionStart", {})
        data = self.read_session("antigravity:c1")
        self.assertEqual((data["agent"], data["cwd"], data["pid"], data["status"]), ("antigravity", "/x/site", 4242, "idle"))
        watch.assert_called_once_with(4242, self.session_file("antigravity:c1"))
        self.agy("PreInvocation", {"invocationNum": 0})
        self.assertEqual(self.read_session("antigravity:c1")["status"], "working")
        self.agy("PreToolUse", {"toolCall": {"name": "run_command", "args": {"CommandLine": "npm test\nmais"}}})
        data = self.read_session("antigravity:c1")
        self.assertEqual((data["current_tool"], data["tool_detail"]), ("run_command", "npm test"))
        self.agy("PostToolUse", {"toolCall": {"name": "run_command", "args": {}}})
        self.assertIsNone(self.read_session("antigravity:c1")["current_tool"])
        self.agy("PreInvocation", {"invocationNum": 1})
        self.assertIsNotNone(self.read_session("antigravity:c1")["turn_started_at"])
        self.agy("Stop", {"terminationReason": "NO_TOOL_CALL"})
        self.assertEqual(self.read_session("antigravity:c1")["status"], "idle")
        day = json.loads(next((self.state / "day").glob("*.json")).read_text())
        self.assertEqual(day["completed_responses"], 1)

    def test_antigravity_file_tools_show_basename(self):
        self.agy("SessionStart", {})
        self.agy("PreToolUse", {"toolCall": {"name": "edit_file", "args": {"Path": "/x/site/src/Hero.tsx"}}})
        self.assertEqual(self.read_session("antigravity:c1")["tool_detail"], "Hero.tsx")

    def test_antigravity_cancel_is_not_a_reply(self):
        self.agy("SessionStart", {})
        self.agy("PreInvocation", {"invocationNum": 0})
        self.agy("Stop", {"terminationReason": "USER_CANCELED"})
        self.assertEqual(self.read_session("antigravity:c1")["status"], "idle")
        self.assertFalse((self.state / "day").exists())

    def test_antigravity_resumed_conversation_is_adopted(self):
        # agy -c não manda SessionStart
        watch = self.agy("PreInvocation", {"invocationNum": 0})
        data = self.read_session("antigravity:c1")
        self.assertEqual((data["status"], data["pid"]), ("working", 4242))
        watch.assert_called_once()

    def test_antigravity_new_conversation_drops_old_of_same_process(self):
        self.agy("SessionStart", {"conversationId": "old"})
        self.agy("SessionStart", {"conversationId": "dead"}, pid=2**22 + 7)
        self.send({"hook_event_name": "SessionStart", "session_id": "claude1"})
        self.agy("SessionStart", {"conversationId": "new"})
        self.assertFalse(self.session_file("antigravity:old").exists())
        self.assertFalse(self.session_file("antigravity:dead").exists())
        self.assertTrue(self.session_file("antigravity:new").exists())
        self.assertTrue(self.session_file("claude1").exists())

    def test_antigravity_session_ends_with_process(self):
        from agent_pet.hooks import _watch_end
        target = self.root / "s.json"
        target.write_text("{}")
        process = subprocess.Popen(["sleep", "0.3"])
        _watch_end(process.pid, target)
        self.assertTrue(target.exists())
        process.wait()
        deadline = time.time() + 5
        while target.exists() and time.time() < deadline:
            time.sleep(0.1)
        self.assertFalse(target.exists())

    def test_session_record_matches_persisted_contract(self):
        self.send({"hook_event_name": "SessionStart", "session_id": "s1", "cwd": "/tmp", "session_title": "t"}, 1000)
        self.send({"hook_event_name": "UserPromptSubmit", "session_id": "s1"}, 2000)
        self.send({"hook_event_name": "PreToolUse", "session_id": "s1", "tool_name": "Bash"}, 3000)
        data = self.read_session("s1")
        self.assertEqual(
            set(data),
            {
                "session_id", "agent", "status", "cwd", "session_title", "current_tool",
                "tool_detail", "attention_reason",
                "started_at", "turn_started_at", "activity_started_at", "updated_at",
            },
        )
        for key in ("started_at", "turn_started_at", "activity_started_at", "updated_at"):
            self.assertIsInstance(data[key], int)

    def test_daily_record_matches_persisted_contract(self):
        now_ms = 1700000000000
        self.send({"hook_event_name": "SessionStart", "session_id": "s1"}, now_ms)
        self.send({"hook_event_name": "UserPromptSubmit", "session_id": "s1"}, now_ms)
        self.send({"hook_event_name": "Stop", "session_id": "s1"}, now_ms + 1000)
        day = datetime.fromtimestamp((now_ms + 1000) / 1000).date().isoformat()
        data = json.loads((self.state / "day" / f"{day}.json").read_text())
        self.assertEqual(set(data), {"date", "completed_responses", "active_seconds"})
        self.assertEqual(data["date"], day)
        self.assertIsInstance(data["completed_responses"], int)
        self.assertIsInstance(data["active_seconds"], int)


class HookTests(unittest.TestCase):
    def test_parallel_sessions_keep_separate_state(self):
        with tempfile.TemporaryDirectory() as temp:
            state = Path(temp) / "state"
            config = Path(temp) / "config.json"
            events = [
                {"hook_event_name": "SessionStart", "session_id": f"s{i}"}
                for i in range(2)
            ]
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(lambda event: handle_event(event, state, config), events))
            self.assertEqual(results, [0, 0])
            records = [json.loads(path.read_text()) for path in (state / "sessions").glob("*.json")]
            self.assertEqual({record["session_id"] for record in records}, {"s0", "s1"})

    def test_invalid_inputs_are_ignored(self):
        invalid = [
            "{",
            json.dumps({"hook_event_name": "Unknown", "session_id": "s1"}),
            json.dumps({"hook_event_name": "SessionStart"}),
            json.dumps({"hook_event_name": "SessionStart", "session_id": ""}),
            json.dumps({"hook_event_name": "SessionStart", "session_id": 3}),
            json.dumps({"hook_event_name": "SessionStart", "session_id": "x" * 257}),
        ]
        with tempfile.TemporaryDirectory() as home:
            with patch.dict(os.environ, {"HOME": home}):
                for payload in invalid:
                    with self.subTest(payload=payload[:20]):
                        with patch("sys.stdin", io.StringIO(payload)), redirect_stdout(io.StringIO()):
                            self.assertEqual(main(), 0)
            state_root = Path(home) / ".local" / "state" / "agent-pet"
            self.assertFalse(list(state_root.glob("sessions/*.json")))

    def test_persistence_failure_is_nonzero_and_silent(self):
        with tempfile.TemporaryDirectory() as home:
            state_parent = Path(home) / ".local" / "state"
            state_parent.parent.mkdir(parents=True)
            state_parent.write_text("not a directory")
            payload = json.dumps({"hook_event_name": "SessionStart", "session_id": "s1"})
            with patch.dict(os.environ, {"HOME": home}), patch("sys.stdin", io.StringIO(payload)):
                output = io.StringIO()
                with redirect_stdout(output):
                    self.assertEqual(main(), 1)
            self.assertEqual(output.getvalue(), "")

    def test_same_session_updates_are_serialized(self):
        import agent_pet.hooks as hooks

        with tempfile.TemporaryDirectory() as temp:
            state = Path(temp) / "state"
            config = Path(temp) / "config.json"
            handle_event({"hook_event_name": "SessionStart", "session_id": "s1"}, state, config, now_ms=1000)
            events = [
                {"hook_event_name": "PreToolUse", "session_id": "s1", "tool_name": "Bash"},
                {"hook_event_name": "PreToolUse", "session_id": "s1", "tool_name": "Write"},
            ]
            active = 0
            max_active = 0
            guard = threading.Lock()
            original_write = hooks._write_json

            def observed_write(path, data):
                nonlocal active, max_active
                with guard:
                    active += 1
                    max_active = max(max_active, active)
                time.sleep(0.02)
                try:
                    return original_write(path, data)
                finally:
                    with guard:
                        active -= 1

            with patch("agent_pet.hooks._write_json", side_effect=observed_write):
                with ThreadPoolExecutor(max_workers=2) as pool:
                    self.assertEqual(list(pool.map(lambda event: handle_event(event, state, config, now_ms=2000), events)), [0, 0])
            self.assertEqual(max_active, 1)
            digest = hashlib.sha256(b"s1").hexdigest()
            data = json.loads((state / "sessions" / f"{digest}.json").read_text())
            self.assertEqual(data["session_id"], "s1")
            self.assertIn(data["current_tool"], {"Bash", "Write"})

    def test_hook_exit_codes(self):
        with tempfile.TemporaryDirectory() as home:
            env = os.environ.copy()
            env["HOME"] = home
            hook = ROOT / "hook" / "pet-hook.py"
            valid = json.dumps({"hook_event_name": "SessionStart", "session_id": "s1"})
            success = subprocess.run([sys.executable, str(hook)], input=valid, text=True, capture_output=True, env=env)
            self.assertEqual(success.returncode, 0)
            state_parent = Path(home) / ".local" / "state"
            shutil.rmtree(state_parent)
            state_parent.write_text("not a directory")
            failure = subprocess.run([sys.executable, str(hook)], input=valid, text=True, capture_output=True, env=env)
            self.assertEqual(failure.returncode, 1)


if __name__ == "__main__":
    unittest.main()
