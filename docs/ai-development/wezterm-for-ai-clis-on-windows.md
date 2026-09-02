---
title: Isolated WezTerm for Grok and Claude on Windows
description: Why Windows Terminal hangs every window when Grok or Claude redraws, and how to run each AI TUI in its own WezTerm process so one freeze cannot take the rest.
tags: [ai, agents, windows, terminals]
---

# Isolated WezTerm for Grok and Claude on Windows

*Why Windows Terminal hangs every window when Grok or Claude redraws, and how to run each AI TUI in its own WezTerm process so one freeze cannot take the rest.*

**Status:** current as of September 2026. Terminal and CLI version numbers move quickly; the process-model claims are sourced from Microsoft's and WezTerm's own docs and dated in [References](#9-references). Machine-specific paths in [section 4](#4-what-is-installed-on-this-machine) are this workstation's install, not a general requirement.

---

## Table of contents

1. [The question](#1-the-question)
2. [Why every Windows Terminal window dies together](#2-why-every-windows-terminal-window-dies-together)
3. [What WezTerm changes — and what it does not](#3-what-wezterm-changes-and-what-it-does-not)
4. [What is installed on this machine](#4-what-is-installed-on-this-machine)
5. [The isolation model](#5-the-isolation-model)
6. [Daily commands](#6-daily-commands)
7. [WezTerm config](#7-wezterm-config)
8. [Confirming isolation and troubleshooting](#8-confirming-isolation-and-troubleshooting)
9. [References](#9-references)

---

## 1. The question

Grok Build and Claude Code are fullscreen terminal UIs. They redraw constantly: spinner, streamed tokens, tool output, alt-screen, title updates. On Windows they run inside a terminal emulator that talks to the console through ConPTY.

The question this guide answers is not "which terminal is nicest". It is: **when Windows Terminal hangs every open window while Grok or Claude is running, is that the TUI, ConPTY, or the emulator — and can WezTerm isolate the hang?**

The observed failure on this machine:

- 4–5 Windows Terminal windows
- 3–5 tabs per window (12–25 tabs total)
- several of those tabs running Grok and/or Claude
- all windows freeze; one idle tab often still accepts keys
- closing the "bad" tab sometimes wedges the whole application

That is not "too many tabs" in the abstract. It is a **shared-process GPU hang**.

## 2. Why every Windows Terminal window dies together

Windows Terminal Process Model 3.0 hosts **every window of a given install in one `WindowsTerminal.exe` process**. Extra windows do not isolate anything. They share one UI process, one AtlasEngine / Direct3D renderer, and one message pump.

`wt -w -1` and "New window" only open another **window in the same process**. There is no supported `--always-new-process` equivalent.

A busy Grok or Claude tab can stall that shared renderer. Then:

| What you see | What is actually happening |
|---|---|
| All windows freeze | Shared GPU present / paint completion is blocked |
| One idle tab still accepts keys | That control is not waiting on the same paint event |
| Closing the frozen tab hangs everything | Teardown waits on `_hPaintCompletedEvent` |
| Desktop feels choppy until DWM restart | Dirty-rect presentation can leave Desktop Window Manager sick |

This matches a cluster of reports against Windows Terminal and against Claude Code's Ink renderer on ConPTY: the whole app stops redrawing while some input still works ([microsoft/terminal#19333](https://github.com/microsoft/terminal/issues/19333)); one window dying takes the rest ([#18458](https://github.com/microsoft/terminal/issues/18458)); long Claude/Codex TUI sessions leave DWM degraded ([#20443](https://github.com/microsoft/terminal/issues/20443)); closing a frozen tab hangs the process ([#13386](https://github.com/microsoft/terminal/issues/13386)); Ink can do 100% full redraws and silently die ([anthropics/claude-code#27360](https://github.com/anthropics/claude-code/issues/27360)); Claude freezes in Windows Terminal ([#12234](https://github.com/anthropics/claude-code/issues/12234)).

!!! note "Count WindowsTerminal.exe, not windows"
    In Task Manager, four visible Terminal windows are almost always **one** `WindowsTerminal.exe`. That single process is the blast radius.

An optional same-day Windows Terminal diagnostic (it does **not** isolate processes) is to turn on software rendering and disable partial invalidation in `settings.json`:

```json
{
  "experimental.rendering.software": true,
  "rendering.disablePartialInvalidation": true
}
```

Software rendering is CPU-heavy. If hangs drop after that, the diagnosis was AtlasEngine/DWM. Isolated WezTerm is then the better long-term host than leaving Windows Terminal on WARP.

## 3. What WezTerm changes — and what it does not

WezTerm is a GPU-accelerated emulator written in Rust. Grok detects it as a first-class terminal (`/doctor`, including a `terminal.wezterm-kitty` finding). Claude lists it as a native Shift+Enter host.

On native Windows, **WezTerm still uses ConPTY**. Switching emulators does not remove that layer. It changes the GPU presenter sitting on top, and — with `--always-new-process` — gives **one OS process per AI window**.

| Failure mode | Isolated WezTerm |
|---|---|
| All Windows Terminal windows freeze together | This is the target fix |
| Desktop-wide DWM stutter after long TUI sessions | Often helps |
| TUI garbles / input dies, window still open | Mixed — often Ink / Grok TUI / ConPTY |
| `claude` / `grok` process exits, shell comes back | Unlikely to help |

WezTerm is not a dump-all-20-tabs-in-one-window replacement. Its mux has its own freeze/crash class at high pane counts ([wezterm#7388](https://github.com/wezterm/wezterm/issues/7388); stack overflow reported near 26+ panes in [#7861](https://github.com/wezterm/wezterm/issues/7861)). Isolation is the point.

Use **nightly**, not the old `20240203` stable. Multiple Claude Code sessions used to crash WezTerm with `STATUS_STACK_OVERFLOW` while walking a cyclic Windows process tree ([#7705](https://github.com/wezterm/wezterm/issues/7705); fixed in [#7706](https://github.com/wezterm/wezterm/pull/7706), merged June 2026).

## 4. What is installed on this machine

Installed 2026-09-02 via Scoop.

| Item | Value |
|---|---|
| Package | Scoop `wezterm-nightly` from the `versions` bucket |
| Version at install | `wezterm 20260901-002820-4fbd6b8e` (`nightly-20260902`) |
| GUI binary | `%USERPROFILE%\scoop\apps\wezterm-nightly\current\wezterm-gui.exe` |
| CLI shim | `%USERPROFILE%\scoop\shims\wezterm.exe` |
| Grok | `%USERPROFILE%\.grok\bin\grok.exe` |
| Claude | `%USERPROFILE%\.local\bin\claude.exe` |

Update later:

```powershell
scoop update wezterm-nightly
```

Nightly downloads are not hash-verified by Scoop. That is expected.

### File map

```text
%USERPROFILE%\.config\wezterm\wezterm.lua  WezTerm config (Lua; Grok /doctor looks here)
%USERPROFILE%\.wezterm.lua                 Fallback that loads the file above
%USERPROFILE%\.wezterm\README.md        Local copy of this setup
%USERPROFILE%\.wezterm\launch-ai.ps1    PowerShell functions (wez-grok, …)
%USERPROFILE%\.wezterm\start-ai.ps1     Start-menu / shortcut entry point
```

Profiles that source the launchers:

- PowerShell 7: `%USERPROFILE%\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- Windows PowerShell 5.1: `%USERPROFILE%\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

Both contain:

```powershell
$wezLaunch = Join-Path $env:USERPROFILE '.wezterm\launch-ai.ps1'
if (Test-Path $wezLaunch) { . $wezLaunch }
```

Start menu folder: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\WezTerm AI\`

| Shortcut | Starts |
|---|---|
| Grok (WezTerm) | Isolated Grok in `C:\code` |
| Claude (WezTerm) | Isolated Claude in `C:\code` |
| WezTerm (isolated shell) | Isolated `pwsh -NoLogo` in `C:\code` |

The `.lnk` files call `wezterm-gui.exe` directly so a PowerShell console does not flash. `start-ai.ps1` is the same entry point if a scripted shortcut is needed:

```powershell
pwsh -NoLogo -File "$env:USERPROFILE\.wezterm\start-ai.ps1" -App grok
```

`-App` is one of `grok`, `claude`, `hyperclaude`, `shell`. Default working directory for shortcuts is `C:\code`.

Optional Explorer context menu (does **not** pass `--always-new-process`; do not use it for AI sessions):

```powershell
reg import "$env:USERPROFILE\scoop\apps\wezterm-nightly\current\install-context.reg"
```

## 5. The isolation model

Each launcher runs:

```text
wezterm-gui.exe start --always-new-process --cwd <current-directory> -- <command>
```

`--always-new-process` is the flag Windows Terminal does not have. It starts a **new `wezterm-gui.exe`**. If one Grok session hangs its renderer, the other windows stay up.

Verified on install: two `wez-new` calls produced two independent `wezterm-gui.exe` processes (different PIDs, same `--always-new-process` command line). Launchers call the real GUI binary under `scoop\apps\wezterm-nightly\current\`, not the Scoop shim, so a wrapper process is not left sitting around.

`launch-ai.ps1` defines:

1. `Get-WezTermCommand` — prefers the nightly `wezterm-gui.exe`
2. `Start-WezIsolated` — `Start-Process` with `start --always-new-process --cwd <dir> -- <command>`
3. `wez-grok` / `wez-claude` / `wez-hyperclaude` / `wez-new` — resolve `grok.exe` / `claude.exe` and forward remaining arguments

### Recommended layout

| Window | Host | Why |
|---|---|---|
| Grok session 1 | `wez-grok` | Own GPU process |
| Grok session 2 | another `wez-grok` | Own GPU process |
| Claude session | `wez-claude` | Own GPU process |
| git / build / ssh | Windows Terminal or `wez-new` | Low redraw; cheap |

**Do not** put 4–5 AI TUIs as tabs in one WezTerm window. That recreates the shared-renderer failure, just in WezTerm's mux.

Keep Windows Terminal installed. Use it for ordinary shells until WezTerm has survived a few heavy days.

## 6. Daily commands

Open a **new** PowerShell tab after install (or `. $PROFILE`) so the functions load. Run them from the repo you care about; `--cwd` is the current directory.

| Command | What it starts |
|---|---|
| `wez-grok` | Grok in a new WezTerm process |
| `wez-claude` | Claude in a new WezTerm process |
| `wez-hyperclaude` | Claude with `--dangerously-skip-permissions` |
| `wez-new` | Isolated PowerShell |
| `wez-new git status` | Isolated window running that command |

Extra arguments are forwarded:

```powershell
wez-grok --yolo
wez-claude --resume
```

Inside an already-open WezTerm window, the launcher menu lists PowerShell 7, Grok, Claude, and Command Prompt. Those open as **tabs in the current process**, so they are fine for a shell, not for a second AI TUI.

### First Grok session

1. `wez-grok`
2. Run `/doctor`
3. Confirm the `terminal.wezterm-kitty` finding is gone
4. Confirm Ctrl+Enter interjects

If `/doctor` still wants Kitty keyboard, the config file is not being loaded (see [section 8](#8-confirming-isolation-and-troubleshooting)).

### First Claude session

If the display flickers or scrollback jumps:

```powershell
$env:CLAUDE_CODE_NO_FLICKER = '1'
wez-claude
```

Or inside Claude: `/tui fullscreen`. That is an Ink renderer issue, not a WezTerm process-model issue.

## 7. WezTerm config

File: `%USERPROFILE%\.config\wezterm\wezterm.lua`. Grok `/doctor` looks here for `enable_kitty_keyboard`. `%USERPROFILE%\.wezterm.lua` loads that file if WezTerm falls back to it. WezTerm watches the loaded file and reloads most options on save.

| Setting | Value | Why |
|---|---|---|
| `enable_kitty_keyboard` | `true` | Grok `/doctor` requires this for Ctrl+Enter |
| `allow_win32_input_mode` | `false` | Win32 input otherwise takes precedence and swallows Kitty chords |
| `scrollback_lines` | `20000` | Long agent transcripts |
| `front_end` | `WebGpu` | DirectX 12 / Vulkan path, independent of WT AtlasEngine |
| `term` | `xterm-256color` | Safe TERM on Windows (no wezterm terminfo) |
| `initial_cols` / `initial_rows` | `160` / `48` | Default 80×24 is a postage stamp on 4K; Grok paints a black pane at that size |
| `gui-startup` | `maximize()` | Each `wezterm start` window fills the monitor |
| `default_prog` | `pwsh.exe -NoLogo` | New tabs without an explicit command |
| `launch_menu` | pwsh / Grok / Claude / cmd | Convenience inside a window |

The maximize hook must spawn with the `cmd` from `wezterm start`, or Grok never runs:

```lua
local mux = wezterm.mux
wezterm.on('gui-startup', function(cmd)
  local _tab, _pane, window = mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)
```

If a WezTerm window itself hangs on the GPU path, edit the config:

1. `config.front_end = 'OpenGL'`
2. If that still hangs: `config.front_end = 'Software'` (CPU-heavy; diagnostic)

Do not turn on a unix-domain mux for this workflow. Mux is how many panes share one process again.

## 8. Confirming isolation and troubleshooting

When it hangs, check Task Manager **before** killing anything.

1. How many `wezterm-gui.exe` processes? One per AI window is correct. One process for every window means something attached to a shared GUI (`--always-new-process` missing).
2. How many `WindowsTerminal.exe` processes? Almost always one for all WT windows — the old failure mode.
3. Event Viewer → Windows Logs → Application: `MoAppHang` on `WindowsTerminal.exe` or `wezterm-gui.exe`, or "Display driver stopped responding and has recovered".

If **only one** WezTerm window is frozen and the others still paint, isolation is working. Kill that one `wezterm-gui.exe`. Resume with `grok -c` or `claude --resume`.

If **all** WezTerm windows freeze together, isolation was bypassed or the hang is below the emulator (GPU driver / DWM / ConPTY). Note GPU CPU, DWM CPU, and whether restarting `dwm.exe` recovers the desktop.

### Grok opens as a tiny black window

WezTerm's default size is 80×24 cells. On a 4K display that is a small floating window, and Grok's fullscreen TUI does not paint — the pane stays black, the tab still says `grok.exe`. Resize or maximize and the TUI appears.

The config now starts at 160×48 and maximizes on `gui-startup`. That only applies to **new** `wezterm start` processes (`wez-grok`, Start menu shortcut, etc.). This window will not pick it up; close it and launch again.

If a new window is still 80×24, the Lua file failed to load (see [Config is ignored](#config-is-ignored)).

### `wez-grok` is not recognized

The function is loaded from the PowerShell profile. Open a new tab, or:

```powershell
. $PROFILE
Get-Command wez-grok
```

### Grok Ctrl+Enter does not interject

Kitty keyboard is on so Grok can negotiate CSI-u when ConPTY allows it. On native Windows, ConPTY flattens CSI-u to a bare CR, so **Win32 input mode must stay on** — that is the encoding ConPTY actually preserves Shift+Enter with. Alt+Enter is unbound from WezTerm fullscreen so Grok's fallback newline chord reaches the PTY.

```lua
config.enable_kitty_keyboard = true
config.allow_win32_input_mode = true
```

`allow_win32_input_mode` is negotiated when the pane starts. Changing it requires a **new** `wez-grok` window, not a config reload. The `terminal.wezterm-kitty` banner can still appear (runtime probe); Shift+Enter should insert a newline anyway.

### Config is ignored

WezTerm loads `%USERPROFILE%\.config\wezterm\wezterm.lua` before `%USERPROFILE%\.wezterm.lua`. A `wezterm.lua` next to `wezterm-gui.exe` is only for portable/thumb-drive mode. Check the debug overlay (`Ctrl+Shift+L` on nightly) if a Lua error falls back to defaults.

```powershell
wezterm ls-fonts
```

If Lua is broken, WezTerm shows an error overlay instead of listing fonts.

### WezTerm is slower / uses more CPU than Windows Terminal

Known. WezTerm's input path can sit at higher CPU than WT. For AI TUIs the trade is process isolation, not minimum CPU. If a window is janky, try `front_end = 'OpenGL'` before Software.

### `pwsh` FailFast when exiting a TUI

WezTerm has historically bundled an older ConPTY pair than Windows Terminal. Exiting some TUIs under WezTerm crashed `pwsh` with `0x80131623` while the same flow was fine in WT ([wezterm#7774](https://github.com/wezterm/wezterm/issues/7774)). If that returns, update nightly.

### Sleep/resume crash (`d3d11.dll`)

Known WezTerm-on-Windows GPU issue after sleep. Relaunch that one window. If it is frequent, switch `front_end` to `OpenGL` or `Software`.

### Uninstall

```powershell
scoop uninstall wezterm-nightly
```

Then remove `%USERPROFILE%\.config\wezterm\`, `%USERPROFILE%\.wezterm.lua`, `%USERPROFILE%\.wezterm\`, the Start menu folder `WezTerm AI`, and the three-line source block from both PowerShell profiles. Grok and Claude binaries are unchanged.

## 9. References

- Grok terminal support (local): `%USERPROFILE%\.grok\docs\user-guide\21-terminal-support.md`
- WezTerm Windows install: https://wezterm.org/install/windows.html
- WezTerm `--always-new-process`: `wezterm start --help`
- WezTerm Kitty keyboard: https://wezterm.org/config/lua/config/enable_kitty_keyboard.html
- WezTerm Win32 input mode: https://wezterm.org/config/lua/config/allow_win32_input_mode.html
- WezTerm `front_end`: https://wezterm.org/config/lua/config/front_end.html
- Claude terminal config: https://code.claude.com/docs/en/terminal-config
- Windows Terminal rendering settings: https://learn.microsoft.com/en-us/windows/terminal/customize-settings/rendering
- Windows Terminal process model (session management spec): https://github.com/microsoft/terminal/blob/main/doc/specs/%235000%20-%20Process%20Model%202.0/%234472%20-%20Windows%20Terminal%20Session%20Management.md
- microsoft/terminal#19333: https://github.com/microsoft/terminal/issues/19333
- microsoft/terminal#18458: https://github.com/microsoft/terminal/issues/18458
- microsoft/terminal#20443: https://github.com/microsoft/terminal/issues/20443
- microsoft/terminal#13386: https://github.com/microsoft/terminal/issues/13386
- anthropics/claude-code#27360: https://github.com/anthropics/claude-code/issues/27360
- anthropics/claude-code#12234: https://github.com/anthropics/claude-code/issues/12234
- wezterm#7705 / #7706 (Claude process-tree stack overflow): https://github.com/wezterm/wezterm/issues/7705
- wezterm#7774 (bundled ConPTY older than Windows Terminal): https://github.com/wezterm/wezterm/issues/7774
- wezterm#7388 / #7861 (mux freeze / high pane count): https://github.com/wezterm/wezterm/issues/7388
