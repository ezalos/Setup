# Plan: WezTerm auto-tmux with unique session naming

## Context

Louis wants every new WezTerm window (ctrl+alt+t) to automatically open inside a tmux session. Each window should get its own unique session. When SSHing from another machine, he needs to identify and attach to the right session easily.

## Design Decisions

- **Naming**: `w-MMDD-HHhMM` (e.g. `w-0208-14h30`), with `-2`, `-3` suffix on same-minute collisions
- **Behavior**: Always create a new tmux session (never auto-attach to existing)
- **SSH discovery**: A `tls` shell function that lists sessions with their running commands and working directories

## Changes

### 1. Modify `dotfiles/wezterm.lua` — add `default_prog`

Set `config.default_prog` to a zsh one-liner that:
1. Generates session name from current date/time: `w-$(date +%m%d-%Hh%M)`
2. If that name already exists (opened two terminals in the same minute), appends `-2`, `-3`, etc.
3. `exec tmux new-session -s "$session_name"` — replaces the shell with tmux, so closing tmux closes the wezterm tab

```lua
config.default_prog = { '/bin/zsh', '-c', [[
  sn="w-$(date +%m%d-%Hh%M)"
  if tmux has-session -t "$sn" 2>/dev/null; then
    i=2
    while tmux has-session -t "${sn}-${i}" 2>/dev/null; do ((i++)); done
    sn="${sn}-${i}"
  fi
  exec tmux new-session -s "$sn"
]] }
```

Note: The outer zsh is non-interactive (just launches tmux). The shell *inside* tmux will be interactive zsh that sources `.zshrc` normally.

### 2. Modify `dotfiles/.zshrc` — add `tls` function

Add a `tls` function near the other aliases (~line 203) that shows tmux sessions with their running commands and CWDs:

```zsh
# tmux session listing with running commands
tls() {
  tmux list-sessions 2>/dev/null || { echo "No tmux sessions"; return 1; }
  echo ""
  local s
  for s in $(tmux list-sessions -F "#{session_name}"); do
    printf "\033[1;36m%s\033[0m\n" "$s"
    tmux list-windows -t "$s" -F "  #{window_index}: #{pane_current_command} @ #{pane_current_path}"
  done
}
```

Example output when SSHing:
```
w-0208-09h30: 1 windows (created Sat Feb  8 09:30:12 2026)
w-0208-14h30: 2 windows (created Sat Feb  8 14:30:45 2026)

w-0208-09h30
  0: nvim @ ~/project
w-0208-14h30
  0: zsh @ ~/Setup
  1: claude @ ~/Setup
```

Then attach with: `tmux attach -t w-0208-14h30`

## Files Modified

1. `dotfiles/wezterm.lua` — add `default_prog` config
2. `dotfiles/.zshrc` — add `tls` function in the alias section

## Verification

1. Open a new WezTerm window → should land inside a tmux session named like `w-0208-14h30`
2. Open a second window within the same minute → should get `w-0208-14h30-2`
3. Run `tls` → should list both sessions with their running commands
4. `tmux detach` → wezterm tab should close (since we used `exec`)
5. From another terminal: `tmux attach -t w-0208-14h30` → should reattach
