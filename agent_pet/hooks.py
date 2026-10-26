import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path


EVENTS = {
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "PostToolUseFailure",
    "PermissionRequest",
    "Notification",
    "Stop",
    "SessionEnd",
    "Interrupt",
    "PreInvocation",
}
AGENTS = {"claude", "codex", "antigravity"}
# agy (Antigravity CLI): o nome do evento vem pelo argumento --event
ANTIGRAVITY_EVENTS = {"SessionStart", "PreInvocation", "PreToolUse", "PostToolUse", "Stop"}
SHELLS = {"sh", "bash", "dash", "zsh", "fish"}
# idle_prompt fica de fora: chega 60 s depois de toda resposta, sem pergunta
ATTENTION_NOTIFICATIONS = {"agent_needs_input"}
# Nesses modos o PermissionRequest vem antes da aprovação automática
AUTO_PERMISSION_MODES = {"auto", "bypassPermissions", "dontAsk"}
DETAIL_LIMIT = 60
APP_NAME = "Retro Agent Pet"
FILE_TOOLS = {"Edit": "file_path", "MultiEdit": "file_path", "Write": "file_path", "Read": "file_path", "NotebookEdit": "notebook_path",
              "read_file": "Path", "write_file": "Path", "edit_file": "Path"}
PATCH_FILE = re.compile(r"^\*\*\* (?:Update|Add|Delete) File: (.+)$", re.MULTILINE)
TEXT_TOOLS = {"Bash": "command", "Grep": "pattern", "Glob": "pattern", "WebSearch": "query", "Task": "description", "Agent": "description",
              "run_command": "CommandLine", "call_mcp_tool": "ToolName"}


def _state_root():
    return Path.home() / ".local" / "state" / "agent-pet"


def _config_path():
    return Path.home() / ".config" / "agent-pet" / "config.json"


def _session_path(state_root, session_id, agent="claude"):
    # Claude mantém o nome antigo; outros agentes ganham prefixo para não colidir
    key = session_id if agent == "claude" else f"{agent}:{session_id}"
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return state_root / "sessions" / f"{digest}.json"


@contextmanager
def _write_lock(state_root):
    state_root.mkdir(parents=True, exist_ok=True)
    lock_path = state_root / ".write.lock"
    with lock_path.open("a", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def _read_json(path, default):
    try:
        with path.open("r", encoding="utf-8") as source:
            value = json.load(source)
    except FileNotFoundError:
        return default
    if not isinstance(value, dict):
        return default
    return value


def _write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, prefix=f".{path.name}.", delete=False
        ) as temp_file:
            temp_name = temp_file.name
            json.dump(data, temp_file, ensure_ascii=False, separators=(",", ":"))
            temp_file.write("\n")
            temp_file.flush()
            os.fsync(temp_file.fileno())
        os.replace(temp_name, path)
    finally:
        if temp_name and os.path.exists(temp_name):
            os.unlink(temp_name)


def _notification_enabled(config_path):
    try:
        config = _read_json(config_path, {"notifications_enabled": True})
    except (OSError, ValueError):
        return True
    # Modo discreto (aba Agentes) também silencia os avisos
    return config.get("notifications_enabled") is not False and config.get("discreet") is not True


def _valid_session_id(value):
    return isinstance(value, str) and 1 <= len(value) <= 256


def _tool_detail(tool_name, tool_input):
    # Resumo curto para a interface: nome do arquivo ou 1ª linha do texto
    if not isinstance(tool_input, dict):
        return None
    if tool_name == "apply_patch":
        match = PATCH_FILE.search(str(tool_input.get("command") or ""))
        if not match:
            return None
        return os.path.basename(match.group(1).strip()) or None
    if tool_name in FILE_TOOLS:
        value = tool_input.get(FILE_TOOLS[tool_name])
        if not isinstance(value, str):
            return None
        return os.path.basename(value) or None
    value = tool_input.get(TEXT_TOOLS.get(tool_name, ""))
    if not isinstance(value, str) or not value.strip():
        return None
    line = value.strip().splitlines()[0].strip()
    return line if len(line) <= DETAIL_LIMIT else line[: DETAIL_LIMIT - 1] + "…"


def _new_session(event, now_ms, agent):
    return {
        "session_id": event["session_id"],
        "agent": agent,
        "status": "idle",
        "cwd": event.get("cwd"),
        "session_title": event.get("session_title"),
        "current_tool": None,
        "tool_detail": None,
        "attention_reason": None,
        "started_at": now_ms,
        "turn_started_at": None,
        "activity_started_at": None,
        "updated_at": now_ms,
    }


def _agent_pid():
    # Primeiro ancestral que não é shell: o processo do agy que chamou o hook
    pid = os.getppid()
    for _ in range(4):
        try:
            name = Path(f"/proc/{pid}/comm").read_text().strip()
            parent = int(Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            return None
        if name not in SHELLS or parent <= 1:
            return pid
        pid = parent
    return pid


def _watch_end(pid, path):
    # agy não tem SessionEnd: apaga a sessão quando o processo sair
    try:
        subprocess.Popen(
            ["sh", "-c", 'tail --pid="$1" -f /dev/null; rm -f "$2"', "sh", str(pid), str(path)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def _drop_process_sessions(state_root, agent, pid, keep):
    # Conversa nova no mesmo processo ou processo que já saiu (ex.: reinício da máquina)
    for path in (state_root / "sessions").glob("*.json"):
        if path == keep:
            continue
        try:
            old = _read_json(path, {})
        except (OSError, ValueError):
            continue
        old_pid = old.get("pid")
        if old.get("agent") == agent and isinstance(old_pid, int) and (old_pid == pid or not os.path.exists(f"/proc/{old_pid}")):
            path.unlink(missing_ok=True)


def from_antigravity(event, event_name):
    if not isinstance(event, dict) or event_name not in ANTIGRAVITY_EVENTS:
        return None
    tool = event.get("toolCall") if isinstance(event.get("toolCall"), dict) else {}
    paths = event.get("workspacePaths")
    # Cancelado ou com erro não é resposta concluída
    if event_name == "Stop" and event.get("terminationReason") in {"USER_CANCELED", "ERROR"}:
        event_name = "Interrupt"
    return {
        "hook_event_name": event_name,
        "session_id": event.get("conversationId"),
        "cwd": paths[0] if isinstance(paths, list) and paths else None,
        "tool_name": tool.get("name"),
        "tool_input": tool.get("args"),
    }


def _notify(args):
    try:
        subprocess.run(
            args,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass


def handle_event(event, state_root=None, config_path=None, now_ms=None, agent="claude"):
    if not isinstance(event, dict):
        return 0
    event_name = event.get("hook_event_name")
    session_id = event.get("session_id")
    if event_name not in EVENTS or not _valid_session_id(session_id):
        return 0

    if now_ms is None:
        now_ms = time.time_ns() // 1_000_000
    state_root = Path(state_root) if state_root else _state_root()
    config_path = Path(config_path) if config_path else _config_path()
    session_path = _session_path(state_root, session_id, agent)
    notification = None
    pid = event.get("pid") if isinstance(event.get("pid"), int) else None
    watch = False

    try:
        with _write_lock(state_root):
            session = _read_json(session_path, None)
            if event_name == "SessionEnd":
                session_path.unlink(missing_ok=True)
                return 0

            # Conversa retomada no agy não manda SessionStart: começa no primeiro evento do processo
            if event_name == "SessionStart" or (pid and (session is None or session.get("pid") != pid)):
                if pid:
                    _drop_process_sessions(state_root, agent, pid, session_path)
                    watch = session is None or session.get("pid") != pid
                if session is None:
                    session = _new_session(event, now_ms, agent)
                else:
                    session.update(
                        agent=agent,
                        status="idle",
                        cwd=event.get("cwd", session.get("cwd")),
                        session_title=event.get("session_title", session.get("session_title")),
                        current_tool=None,
                        tool_detail=None,
                        attention_reason=None,
                        turn_started_at=None,
                        activity_started_at=None,
                        updated_at=now_ms,
                    )
                if pid:
                    session["pid"] = pid
            elif session is None:
                return 0

            if event_name == "PreInvocation":
                # agy chama o modelo várias vezes por turno; a primeira abre o turno
                if session.get("status") != "working":
                    session["turn_started_at"] = now_ms
                session.update(
                    status="working",
                    current_tool=None,
                    tool_detail=None,
                    attention_reason=None,
                    activity_started_at=None,
                )
            elif event_name == "UserPromptSubmit":
                session.update(
                    status="working",
                    current_tool=None,
                    tool_detail=None,
                    attention_reason=None,
                    activity_started_at=None,
                    turn_started_at=now_ms,
                )
            elif event_name == "PreToolUse":
                session.update(
                    status="working",
                    current_tool=event.get("tool_name"),
                    tool_detail=_tool_detail(event.get("tool_name"), event.get("tool_input")),
                    attention_reason=None,
                    activity_started_at=now_ms,
                )
            elif event_name in {"PostToolUse", "PostToolUseFailure"}:
                session.update(
                    status="working",
                    current_tool=None,
                    tool_detail=None,
                    attention_reason=None,
                    activity_started_at=None,
                )
            elif event_name == "Stop":
                turn_started_at = session.get("turn_started_at")
                elapsed = max(0, now_ms - turn_started_at) // 1000 if isinstance(turn_started_at, int) else 0
                day = datetime.fromtimestamp(now_ms / 1000).date().isoformat()
                day_path = state_root / "day" / f"{day}.json"
                summary = _read_json(
                    day_path,
                    {"date": day, "completed_responses": 0, "active_seconds": 0},
                )
                summary["completed_responses"] = int(summary.get("completed_responses", 0)) + 1
                summary["active_seconds"] = int(summary.get("active_seconds", 0)) + elapsed
                _write_json(day_path, summary)
                session.update(
                    status="idle",
                    current_tool=None,
                    tool_detail=None,
                    attention_reason=None,
                    activity_started_at=None,
                    turn_started_at=None,
                )
            elif event_name == "Interrupt":
                session.update(
                    status="idle",
                    current_tool=None,
                    tool_detail=None,
                    attention_reason=None,
                    activity_started_at=None,
                    turn_started_at=None,
                )
            elif event_name == "PermissionRequest":
                if agent == "claude" and event.get("permission_mode") in AUTO_PERMISSION_MODES:
                    return 0
                session.update(
                    status="attention",
                    attention_reason="permission",
                    current_tool=event.get("tool_name"),
                    tool_detail=_tool_detail(event.get("tool_name"), event.get("tool_input")),
                    activity_started_at=now_ms,
                )
                # Claude Code avisa depois, pelo permission_prompt, se o pedido ficar esperando
                if agent != "claude" and _notification_enabled(config_path):
                    tool_name = event.get("tool_name") or agent
                    cwd = event.get("cwd") or session.get("cwd") or ""
                    notification = ["notify-send", f"{APP_NAME} · {tool_name}", cwd]
            elif event_name == "Notification":
                notification_type = event.get("notification_type")
                if notification_type == "permission_prompt":
                    # Diálogo aberto há ~6 s: aí sim precisa de você
                    session.update(status="attention", attention_reason="permission")
                    if not session.get("activity_started_at"):
                        session["activity_started_at"] = now_ms
                    if _notification_enabled(config_path):
                        tool_name = session.get("current_tool") or "Claude Code"
                        notification = ["notify-send", f"{APP_NAME} · {tool_name}", event.get("cwd") or session.get("cwd") or ""]
                elif notification_type not in ATTENTION_NOTIFICATIONS:
                    return 0
                else:
                    session.update(status="attention", attention_reason="input", activity_started_at=now_ms)
                    if _notification_enabled(config_path):
                        notification = [
                            "notify-send",
                            event.get("title") or APP_NAME,
                            event.get("message") or "Claude Code precisa de você",
                        ]

            session["agent"] = agent
            session["updated_at"] = now_ms
            _write_json(session_path, session)
    except (OSError, ValueError, TypeError):
        return 1

    if watch:
        _watch_end(pid, session_path)
    if notification:
        _notify(notification)
    return 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    agent = argv[1] if len(argv) >= 2 and argv[0] == "--agent" and argv[1] in AGENTS else "claude"
    if agent == "antigravity":
        # agy espera JSON na saída; {} não decide nada
        print("{}")
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return 0
    if agent == "antigravity":
        event_name = argv[3] if len(argv) == 4 and argv[2] == "--event" else None
        event = from_antigravity(event, event_name)
        if event is None:
            return 0
        event["pid"] = _agent_pid()
        # No agy, código 1 no PreToolUse pode barrar a ferramenta: o pet nunca atrapalha o agente
        handle_event(event, agent=agent)
        return 0
    return handle_event(event, agent=agent)


if __name__ == "__main__":
    raise SystemExit(main())
