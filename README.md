# Retro Agent Pet

**A tiny retro computer on the Omarchy bar that keeps an eye on your coding agents.**

![Retro Agent Pet panel: home with usage gauges, sessions and limits](preview.png)

Retro Agent Pet watches your local **Claude Code** and **Codex** sessions and shows,
at a glance, who is working, who is waiting for you and how much of each
agent's usage limit is left. The little computer on the bar changes face with
the state of your sessions: it works, celebrates, sleeps, and blinks red when an
agent asks for permission.

> The panel supports Brazilian Portuguese and English.

## Screens

A small menu at the bottom of the panel switches between the screens below (named
in Portuguese here; in English they are Home, Sessions, Limits, Usage, Request,
Agents and About). All screens share a 320 × 560 px panel (clamped to the
available screen space). The bottom menu stays in place while long lists scroll;
the home pet is larger and keeps its square proportions:

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
  no notifications and no blinking icon. **Idioma** switches between Portuguese
  and English (automatic follows your system `LANG`). **Sessões** shows whether the session
  hooks are installed, with an **Ativar** button that installs them. **Personagem**
  offers live previews of Computer, Cat, Robot and Dog; your choice is saved in
  `~/.config/agent-pet/config.json` (`character`: `computer`, `cat`, `robot`, `dog`)
  and applies to the bar and panel. Missing or unknown values use Computer.
- **ⓘ Sobre** — version, license and credits: author, e-mail and project links.

## Install

```bash
omarchy plugin add https://github.com/MarlonAzevedo/omarchy-retro-agent-pet.git --enable
```

`--enable` puts the pet on the right side of the bar. Usage, limits, focus and
today's summary work right away. To follow your sessions, open the panel's
**Agentes** screen and click **Ativar** next to **Sessões**, or run the same setup
from a terminal, which asks for confirmation:

```bash
~/.config/omarchy/plugins/io.github.marlonazevedo.agent-pet/bin/agent-pet setup
```

Setup adds asynchronous hooks to `~/.claude/settings.json` and, when Codex is
installed, to `~/.codex/hooks.json`. Both files are backed up first and your
existing hooks are kept; nothing is written until you click or confirm. Codex runs new or changed hooks only after you
trust them: start a new Codex session and choose **Trust all and continue** when it
asks (`/hooks` shows whether they are active).

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
- Claude Code and/or Codex. Usage and limits come from Omarchy's own collectors
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
`~/.claude/settings.json` and `~/.codex/hooks.json`.

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
| `language` | `"auto"` | Panel and notification language: `"pt"`, `"en"` or `"auto"` (from `LANG`); managed by the **Agentes** screen. |
| `focus_rounds` | `4` | Focus rounds per timer started from the panel. |
| `character` | `"computer"` | `"computer"`, `"cat"`, `"robot"` or `"dog"`; shared by the panel and CLI. |

## Command line

The CLI is included at `bin/agent-pet` in the plugin directory. To call it as
`agent-pet` from any terminal, create a symlink once (without replacing an existing command):

```bash
mkdir -p ~/.local/bin
ln -s ~/.config/omarchy/plugins/io.github.marlonazevedo.agent-pet/bin/agent-pet ~/.local/bin/agent-pet
```

Make sure `~/.local/bin` is in your `PATH`, or use the full plugin path instead.

```bash
agent-pet status             # Visible sessions, focus, character and usage-limit snapshots
agent-pet status --json      # Machine-readable output
agent-pet focus 25 5 4       # Start 4 work rounds of 25 min, with 5 min breaks
agent-pet focus              # Show the current focus timer (also: focus status)
agent-pet focus pause
agent-pet focus resume
agent-pet focus stop
agent-pet pet                # Show the current character
agent-pet pet dog            # computer, cat, robot or dog
agent-pet --help
```

Focus uses the same timer as the panel: there is no break after the last round,
and pause/resume preserves time remaining. Starting a timer replaces the current
one. Work accepts 1–1440 minutes, breaks 0–1440 minutes and rounds 1–100.
Character changes preserve the other preferences and appear in the panel and bar.
Queries do not write state or launch usage collectors; usage limits are the latest
snapshots already collected by Omarchy. Hidden agents are omitted from `status`.

Like the panel, the CLI respects `XDG_CONFIG_HOME` and `XDG_STATE_HOME`, falling
back to `~/.config` and `~/.local/state`. Terminal messages are in Portuguese;
`status --json` uses stable English keys (`sessions`, `focus`, `character`, `usage`).
Invalid arguments return 2; file or state errors return 1. Existing `setup` and
`check` commands remain available with their original exit codes.

## Development

```bash
python3 -B -m unittest discover -s testes -t .
node testes/model.test.mjs
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml6 -I testes/painel/imports testes/painel/alignment.qml
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml6 testes/painel/robot-animation.qml
QT_QPA_PLATFORM=offscreen qml6 -I testes/painel/imports testes/painel/render.qml -- /tmp/agent-pet-render
```

The last command renders every panel screen with test data, outside the shell.
After changing QML in an installed copy, run `omarchy-restart-shell`: the shell's
hot reload keeps components it already compiled.

## Português

Retro Agent Pet é um computadorzinho na barra do Omarchy que acompanha as sessões
locais do Claude Code e do Codex: quem está trabalhando, quem precisa de você,
os limites e o uso de cada agente (tokens por dia e por modelo) e o resumo do
dia, com um timer de foco (pomodoro) e um modo discreto. O clique direito abre o agente padrão, e o widget Agents do Omarchy pode
ser desativado. Instale com o comando da seção **Install** e, para acompanhar as sessões, clique em
**Ativar** na tela Agentes; no Codex, aprove os hooks ao abrir uma sessão nova ("Trust all and continue"). Tudo fica
na sua máquina.

## Credits

Created by **Marlon Azevedo** — <foxwnobr@gmail.com> ·
[github.com/MarlonAzevedo](https://github.com/MarlonAzevedo).
Bugs and ideas: [open an issue](https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/issues).

Usage and limits come from the collectors of Omarchy's Agents widget. Inspired
by [Mupli](https://mupli.io).

## License

[MIT](LICENSE)
