# Retro Agent Pet

**A tiny retro computer on the Omarchy bar that keeps an eye on your coding agents.**

![Retro Agent Pet panel: home with usage gauges, sessions and limits](preview.png)

Retro Agent Pet watches your local **Claude Code**, **Codex** and **Antigravity CLI**
(`agy`) sessions and shows,
at a glance, who is working, who is waiting for you and how much of each
agent's usage limit is left. The little computer on the bar changes face with
the state of your sessions: it works, celebrates, sleeps, and blinks red when an
agent asks for permission.

> The interface is in Brazilian Portuguese.

## Screens

A small menu at the bottom of the panel switches between:

- **Início** — the pet, one circular gauge per usage window of the selected
  agent (Claude Code 5h/7d, Codex 30d) and today's completed replies and active
  time, plus a focus timer (pomodoro): pick 25/5 or 50/10, then pause, resume
  or stop. Minutes left show next to the bar icon, the pet wears headphones while
  you focus and a notification marks each step. The timer lives in
  `~/.local/state/agent-pet/focus.json`, so it keeps running with the panel
  closed or the shell restarted.
- **Sessões** — one card per session: project, agent, current activity
  (`Editando Hero.tsx`, `Bash · npm test`) and how long it has been running.
- **Limites** — the main window of the selected agent in a big gauge and, when
  the current pace would run out before the reset, the time it would happen.
- **Uso** — the same usage view as Omarchy's Agents widget, per agent: plan,
  today's prompts, sessions and tokens, tokens per day for the last week and
  tokens per model.
- **Pedido** — opens by itself when a session asks for permission: project,
  the requested command (`Bash: npm run migrate`) and how long it has waited.
- **Agentes** — every agent Omarchy tracks, with a switch to hide it (and its
  sessions and gauges) from the other screens, and the **discreet mode** switch:
  no notifications and no blinking icon.
- **ⓘ Sobre** — version, license and credits: author, e-mail and project links.

## Install

```bash
omarchy plugin add https://github.com/MarlonAzevedo/omarchy-retro-agent-pet.git --enable
~/.config/omarchy/plugins/io.github.marlonazevedo.agent-pet/bin/agent-pet setup
```

`--enable` puts the pet on the right side of the bar. `agent-pet setup` asks for
confirmation and then adds asynchronous hooks to `~/.claude/settings.json` and,
when Codex is installed, to `~/.codex/hooks.json`. Both files are backed up first
and your existing hooks are kept. Codex runs new hooks only after you review and
trust them: open Codex and run `/hooks`.

When the Antigravity CLI is installed (`~/.gemini/config/` exists), setup also adds
a `retro-agent-pet` block to `~/.gemini/config/hooks.json`. `agy` has no session-end
or permission hook, so its sessions show work and idle (never "needs you") and
leave the panel when the `agy` process exits. Usage and limits are not collected
for Antigravity.

Left click opens the panel; right click launches your default agent
(`omarchy-agent --pick`), like the Agents widget. To open it from the keyboard,
add a binding to `~/.config/hypr/bindings.lua` (pick a free key with
`omarchy menu keybindings --print`):

```lua
o.bind("SUPER + ALT + A", "Retro Agent Pet", "omarchy-shell shell toggle io.github.marlonazevedo.agent-pet")
```

The widget stays hidden until a session starts or Omarchy has recorded agent
usage. It loads the Agents widget's data layer (`plugins/agents/Main.qml` from
the Omarchy Shell), which refreshes the usage records, so the Agents widget
itself can be turned off: `omarchy plugin disable omarchy.agents`.

### Requirements

- Omarchy 4 (Omarchy Shell) and `python3`.
- Claude Code, Codex and/or Antigravity CLI. Usage and limits come from Omarchy's own collectors
  (`omarchy-agent-usage-update`); for Codex, install it the Omarchy way
  (`omarchy-mise-install codex`) so the collector can find it.

### Update

```bash
omarchy plugin update io.github.marlonazevedo.agent-pet
omarchy-restart-shell
```

### Remove

```bash
omarchy plugin remove io.github.marlonazevedo.agent-pet
rm -rf ~/.local/state/agent-pet ~/.config/agent-pet   # optional: state and settings
```

Then delete the hook entries that run `pet-hook.py` from
`~/.claude/settings.json` and `~/.codex/hooks.json`, and the `retro-agent-pet`
block from `~/.gemini/config/hooks.json`.

## Privacy

Everything stays on your machine; nothing is sent over the network and no
transcript is read. Each session is a small JSON file in
`~/.local/state/agent-pet/sessions/` (mode `600`) with status, project folder,
current tool and a short tool summary: a file name, a search pattern or the first
line of a shell command cut at 60 characters. Desktop notifications show only the
tool name and folder.

## Settings

`~/.config/agent-pet/config.json`:

| Key | Default | |
|---|---|---|
| `notifications_enabled` | `true` | Desktop notification when an agent needs you. |
| `hidden_agents` | `[]` | Agent ids hidden in the panel; managed by the **Agentes** screen. |
| `discreet` | `false` | Discreet mode: no notifications, no blinking icon; managed by the **Agentes** screen. |
| `focus_rounds` | `4` | Focus rounds per timer. |

## Development

```bash
python3 -B -m unittest discover -s testes -t .
node testes/model.test.mjs
QT_QPA_PLATFORM=offscreen qml6 -I testes/painel/imports testes/painel/render.qml -- /tmp/agent-pet-render
```

The last command renders every panel screen with test data, outside the shell.
After changing QML in an installed copy, run `omarchy-restart-shell`: the shell's
hot reload keeps components it already compiled.

## Português

Retro Agent Pet é um computadorzinho na barra do Omarchy que acompanha as sessões
locais do Claude Code, do Codex e do Antigravity CLI: quem está trabalhando, quem precisa de você,
os limites e o uso de cada agente (tokens por dia e por modelo) e o resumo do
dia, com um timer de foco (pomodoro) e um modo discreto. O clique direito abre o agente padrão, e o widget Agents do Omarchy pode
ser desativado. Instale com os dois comandos
da seção **Install**, aprove os hooks no Codex com `/hooks` e pronto. Tudo fica
na sua máquina.

## Credits

Created by **Marlon Azevedo** — <foxwnobr@gmail.com> ·
[github.com/MarlonAzevedo](https://github.com/MarlonAzevedo).
Bugs and ideas: [open an issue](https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/issues).

Usage and limits come from the collectors of Omarchy's Agents widget. Inspired
by [Mupli](https://mupli.io).

## License

[MIT](LICENSE)
