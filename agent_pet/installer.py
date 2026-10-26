import json
import os
import shlex
import shutil
import stat
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


EVENTS = {
    "SessionStart": None,
    "UserPromptSubmit": None,
    "PreToolUse": None,
    "PostToolUse": None,
    "PostToolUseFailure": None,
    "PermissionRequest": None,
    "Notification": "agent_needs_input|permission_prompt",
    "Stop": None,
    "SessionEnd": None,
}
# Codex não tem Notification nem PostToolUseFailure; tem Interrupt
CODEX_EVENTS = {
    "SessionStart": None,
    "UserPromptSubmit": None,
    "PreToolUse": None,
    "PostToolUse": None,
    "PermissionRequest": None,
    "Stop": None,
    "SessionEnd": None,
    "Interrupt": None,
}
# Antigravity CLI (agy): blocos com nome; eventos de ferramenta usam matcher
ANTIGRAVITY_HOOK = "retro-agent-pet"
ANTIGRAVITY_EVENTS = ("SessionStart", "PreInvocation", "PreToolUse", "PostToolUse", "Stop")
ANTIGRAVITY_TOOL_EVENTS = {"PreToolUse", "PostToolUse"}


def write_settings_atomically(path, content):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile(mode="wb", dir=path.parent, prefix=f".{path.name}.", delete=False) as temp_file:
            temp_name = temp_file.name
            mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
            os.fchmod(temp_file.fileno(), mode)
            temp_file.write(content)
            temp_file.flush()
            os.fsync(temp_file.fileno())
        os.replace(temp_name, path)
    finally:
        if temp_name and os.path.exists(temp_name):
            os.unlink(temp_name)


def _hook_command(project_root, agent=None):
    script = Path(project_root) / "hook" / "pet-hook.py"
    command = f"{shlex.quote(sys.executable)} {shlex.quote(str(script.resolve()))}"
    return f"{command} --agent {agent}" if agent else command


def _drop_stale_hooks(hooks, command):
    # Remove o pet-hook.py de outro caminho (ex.: instalação anterior) para não gravar duas vezes
    for event_name, groups in list(hooks.items()):
        if not isinstance(groups, list):
            continue
        kept_groups = []
        for group in groups:
            if isinstance(group, dict) and isinstance(group.get("hooks"), list):
                kept = [
                    item for item in group["hooks"]
                    if not (isinstance(item, dict) and "pet-hook.py" in str(item.get("command", "")) and item.get("command") != command)
                ]
                if not kept:
                    continue
                group["hooks"] = kept
            kept_groups.append(group)
        hooks[event_name] = kept_groups


def _merge_hooks(settings, command, events=EVENTS):
    hooks = settings.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("hooks must be an object")
    _drop_stale_hooks(hooks, command)
    for event_name, matcher in events.items():
        groups = hooks.setdefault(event_name, [])
        if not isinstance(groups, list):
            raise ValueError(f"hooks.{event_name} must be an array")
        installed = any(
            isinstance(group, dict)
            and isinstance(group.get("hooks"), list)
            and any(
                isinstance(item, dict) and item.get("command") == command
                for item in group["hooks"]
            )
            for group in groups
        )
        if installed:
            continue
        group = {"hooks": [{"type": "command", "command": command, "async": True}]}
        if matcher:
            group["matcher"] = matcher
        groups.append(group)
    return settings


def _merge_antigravity(settings, project_root):
    # O bloco é todo do Agent Pet: regravar resolve caminho antigo e duplicata
    spec = {}
    for event_name in ANTIGRAVITY_EVENTS:
        handler = {"type": "command", "command": f"{_hook_command(project_root, 'antigravity')} --event {event_name}", "timeout": 5}
        spec[event_name] = [{"matcher": "", "hooks": [handler]}] if event_name in ANTIGRAVITY_TOOL_EVENTS else [handler]
    settings[ANTIGRAVITY_HOOK] = spec
    return settings


def _targets(project_root, settings_path, codex_hooks_path=None, antigravity_hooks_path=None):
    targets = [(Path(settings_path), lambda settings: _merge_hooks(settings, _hook_command(project_root), EVENTS))]
    if codex_hooks_path:
        targets.append((Path(codex_hooks_path), lambda settings: _merge_hooks(settings, _hook_command(project_root, "codex"), CODEX_EVENTS)))
    if antigravity_hooks_path:
        targets.append((Path(antigravity_hooks_path), lambda settings: _merge_antigravity(settings, project_root)))
    return targets


def _plan(targets):
    plans = []
    for path, merge in targets:
        settings = _read_settings(path)
        plans.append((path, settings, merge(json.loads(json.dumps(settings)))))
    return plans


def _backup_path(settings_path):
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    return settings_path.with_name(f"{settings_path.name}.bak.{stamp}")


def _write_default_config(config_path):
    if config_path.exists():
        return False
    write_settings_atomically(config_path, b'{"notifications_enabled":true}\n')
    return True


def _read_settings(settings_path):
    original = settings_path.read_bytes() if settings_path.exists() else b"{}\n"
    try:
        settings = json.loads(original)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError(f"invalid JSON in {settings_path}") from error
    if not isinstance(settings, dict):
        raise ValueError(f"{settings_path} must contain an object")
    return settings


def _write_merged(settings_path, settings, merged):
    if merged == settings:
        return
    if settings_path.exists():
        shutil.copy2(settings_path, _backup_path(settings_path))
    write_settings_atomically(settings_path, (json.dumps(merged, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def install(settings_path, config_path, project_root, confirm, codex_hooks_path=None, antigravity_hooks_path=None):
    config_path = Path(config_path)
    plans = _plan(_targets(project_root, settings_path, codex_hooks_path, antigravity_hooks_path))
    if not confirm:
        return 2

    created_config = False
    try:
        created_config = _write_default_config(config_path)
        for path, settings, merged in plans:
            _write_merged(path, settings, merged)
        return 0
    except OSError:
        if created_config:
            config_path.unlink(missing_ok=True)
        raise


def setup():
    home = Path.home()
    root = Path(__file__).resolve().parents[1]
    settings_path = home / ".claude" / "settings.json"
    config_path = home / ".config" / "agent-pet" / "config.json"
    codex_home = Path(os.environ.get("CODEX_HOME") or home / ".codex")
    codex_hooks_path = codex_home / "hooks.json" if codex_home.is_dir() else None
    antigravity_config = home / ".gemini" / "config"
    antigravity_hooks_path = antigravity_config / "hooks.json" if antigravity_config.is_dir() else None
    print(f"Será instalado o monitor de sessões em {settings_path}.")
    if codex_hooks_path:
        print(f"Codex encontrado: também em {codex_hooks_path} (aprove depois com /hooks no Codex).")
    if antigravity_hooks_path:
        print(f"Antigravity CLI encontrado: também em {antigravity_hooks_path}.")
    try:
        plans = _plan(_targets(root, settings_path, codex_hooks_path, antigravity_hooks_path))
        if any(merged != settings for _, settings, merged in plans):
            print("Os hooks serão mesclados à configuração existente; os hooks atuais serão preservados.")
        else:
            print("Os hooks já estão instalados.")
        try:
            answer = input("Aplicar a instalação? [s/N] ").strip().lower()
        except EOFError:
            return 2
        if answer not in {"s", "sim", "y", "yes"}:
            return 2
        return install(settings_path, config_path, root, True, codex_hooks_path, antigravity_hooks_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Falha na instalação: {error}", file=sys.stderr)
        return 1
