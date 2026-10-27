# Changelog

All notable changes to Retro Agent Pet are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Persistent character picker with live previews on the Agents screen: Computer,
  Cat, Robot and Dog, using theme colors and animated session states.
- Detailed 32×32 pets in the panel, with shading, facial details and character
  features; the bar keeps the readable 16×16 sprites.
- A draggable scrollbar appears when panel content exceeds the available height,
  keeping long session lists accessible with the navigation menu fixed in place.
- Robot animation with antenna lights and moving arms,
  following the other pets: animated while working, waiting for attention or near
  a usage limit; stationary while idle.

### Fixed

- Align the character picker with the other preferences and widen the panel to
  keep all four character names readable.
- Keep every screen at the same panel size with a fixed bottom menu, scrollable
  content, larger pets on Home and About, and larger Home and Limits gauges.

## [0.6.0] - 2026-10-27

### Added

- **Ativar** button on the Agentes screen: it installs the session hooks
  (`agent-pet setup --yes`, with the same backups), so installing the plugin is a
  single `omarchy plugin add … --enable` and setup is no longer a required step.
  `agent-pet check` reports whether the hooks are installed.
- English and Portuguese. The panel and the "needs you" notification follow the
  system `LANG` (Portuguese for `pt_*`, English otherwise), or the language picked on
  the Agentes screen (`language` in `config.json`).

## [0.5.0] - 2026-10-27

### Removed

- Antigravity CLI (`agy`) support. `agy` 1.4.8 blocked every tool call while the pet
  was installed, and its usage is not collected, so following it was not worth it.
  `agent-pet setup` removes the old `retro-agent-pet` block from
  `~/.gemini/config/hooks.json` (with a backup); run it after updating, or delete the
  block by hand. Antigravity sessions left in `~/.local/state/agent-pet/sessions/`
  (for example after a reboot) can be deleted.

## [0.4.0] - 2026-10-26

### Added

- Antigravity CLI (`agy`) sessions. When `~/.gemini/config/` exists, `agent-pet setup`
  adds a `retro-agent-pet` block to `~/.gemini/config/hooks.json`. Sessions show the
  project, the current tool ("Rodando npm test", "Editando Hero.tsx") and today's
  replies. `agy` has no session-end hook, so a session leaves the panel when the
  `agy` process exits; a resumed conversation (`agy -c`) is picked up on its first
  event. `agy` has no permission hook and Omarchy does not collect its usage, so
  Antigravity never shows as "needs you" and has no limits.

### Fixed

- Notifications without a real request. Claude Code fires `PermissionRequest`
  before auto mode approves a tool, and `idle_prompt` about 60 seconds after every
  reply. Permission is now announced by the `permission_prompt` notification (the
  dialog has waited about six seconds), `PermissionRequest` is ignored in the
  `auto`, `bypassPermissions` and `dontAsk` modes, and `idle_prompt` no longer counts
  as attention. Codex is unchanged.
- An Antigravity turn that ended in an error (for example, an exhausted quota) or
  was cancelled counted as a completed reply.
- The Antigravity hook always exits with 0: an error there could block the tool in
  `agy` when the state folder cannot be written.
- Codex `SessionEnd` is installed without `async`, which Codex ignored with a warning
  in `/hooks`. Running `agent-pet setup` again fixes existing installs.
- README and setup now say that Codex asks to trust new or changed hooks when a new
  session starts ("Trust all and continue"); `/hooks` only shows their state.

## [0.3.0] - 2026-10-25

### Added

- Focus timer (pomodoro) on the Início screen: 25/5 or 50/10, pause, resume and
  stop, minutes next to the bar icon and a notification at each step.
- Discreet mode on the Agentes screen: no notifications and no blinking icon.
- Keyboard shortcut instructions (`omarchy-shell shell toggle`).

## [0.2.0] - 2026-10-25

### Changed

- Renamed to Retro Agent Pet; the plugin id did not change.

### Added

- About screen with version, license and credits.

## [0.1.0] - 2026-10-25

### Added

- First public version: Claude Code and Codex sessions through hooks, a pixel-art
  retro computer on the bar, and the Início, Sessões, Limites, Uso, Pedido and
  Agentes screens, with usage and limits from Omarchy's own collectors.

[Unreleased]: https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/compare/5be276e...v0.4.0
[0.3.0]: https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/compare/50e8ff6...5be276e
[0.2.0]: https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/compare/caa2d9d...50e8ff6
[0.1.0]: https://github.com/MarlonAzevedo/omarchy-retro-agent-pet/commit/caa2d9d
