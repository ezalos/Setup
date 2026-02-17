# Plan: tmux phantom/stale window cleanup

## Context

Louis uses tmux heavily and accumulates two types of junk windows:
1. **Phantom windows** — opened but never used (just a shell prompt, no commands ever typed)
2. **Stale sessions** — used at some point but long since abandoned (detached, idle for days)

Currently `tls` shows sessions/windows but no idle time, making it hard to spot these. It also prints a distracting raw `tmux list-sessions` dump before the formatted output. The goal is to fix `tls`, add idle time + sorting, and add a new `tclean` for automated detection + interactive cleanup.

## File to modify

`/home/ezalos/Setup/dotfiles/.zshrc` — tmux helpers section (lines 214–243)

## Changes

### 1. Add `_tmux_idle_fmt` helper (new, insert before `tls`)

Converts an epoch timestamp to human-readable idle string ("2d 5h", "15m", "3s").
- Takes epoch timestamp as `$1`, computes delta via `date +%s`
- Two-unit display: days+hours, hours+minutes, then just minutes or seconds
- Shared by both `tls` and `tclean`

### 2. Enhance `tls` (replace lines 215–223)

**Bug fix**: Line 216 `tmux list-sessions 2>/dev/null` prints raw session list to stdout as a side-effect of the existence check. Fix: `tmux list-sessions &>/dev/null` to suppress both stdout and stderr.

**New features**:
- **(attached)** in green / **(detached)** in yellow next to session name
- Per-window idle time in dim text, e.g. `(2d 5h ago)`
- **Sort sessions from oldest-interacted to most-recent** (by `session_activity`), so fresh sessions are at the bottom where your eye naturally lands
- Uses `${(f)"$(...)"}` zsh pattern to iterate lines without subshell issues
- Uses `window_activity` (confirmed working on tmux 3.2a; `pane_activity` is empty)

Sorting approach: pipe `tmux list-sessions -F '#{session_activity}|#{session_name}'` through `sort -n` then extract session names in order.

### 3. Add `tclean` function (new, after `tls`)

```
tclean [--stale|-s] [--hours N|-h N] [--dry-run|-n] [--help]
```

**`--help`**: prints usage with flag descriptions and exits.

**Phantom detection** (default, always runs):
- Scans all windows via `tmux list-windows -a`
- Matches: `pane_current_command` ∈ {zsh, bash, sh} AND `history_size` == 0 AND `cursor_y` <= 5
- These are windows where nothing was ever typed

**Stale detection** (with `--stale`):
- Scans sessions where `session_attached` == 0
- Matches: all windows are shell-only AND `session_activity` older than threshold (**default 72h / 3 days**)
- Skips sessions already fully caught by phantom detection (all windows hist==0)
- Shows pane content preview via `tmux capture-pane -t TARGET -p | tail -5`

**Safety**:
- Never lists current session:window (detected via `$TMUX` + `tmux display-message -p`)
- Non-shell panes (claude, make, nvim, etc.) always skipped
- Dry-run mode with `--dry-run`/`-n`

**Interaction**:
- Shows numbered list with reasons and previews
- Prompt: `Kill? [y/N/numbers]: `
- `y` kills all, space-separated numbers kill selected (e.g. `1 3 5`), anything else aborts
- Kill logic: if last window in session → `kill-session`; else → `kill-window`

**Subshell fix**: Uses `for line in ${(f)"$(...)"}` instead of `... | while read` to avoid zsh subshell scoping issues with arrays (matches existing pattern on line 237).

## Verification

1. `source ~/.zshrc` — no syntax errors
2. `tls` — verify: no raw session dump, sessions sorted oldest→newest, idle times correct, attached/detached labels
3. `tclean --help` — prints usage
4. `tclean` — should detect the ~6 known phantom windows (sessions 5, 17, 19, 20, vscode_Notebooks2Teach, vscode_kta-maps)
5. `tclean --dry-run` — shows candidates, kills nothing
6. `tclean --stale` — additionally shows stale sessions like w-0209-20h39 (idle 7+ days, above 3-day default)
7. `tclean --stale --hours 12` — lowers threshold, catches more sessions
8. Test selective kill with space-separated numbers
9. Verify current window is never listed
