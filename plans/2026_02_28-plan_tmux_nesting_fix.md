# Plan: Fix `ta` to avoid nested tmux sessions

## Context

Louis is always inside a tmux session (WezTerm auto-creates one). When running `ta xxx` to switch sessions, `tmux attach-session` creates a nested tmux — which is bad. We need `ta` to detect it's already inside tmux and use the right command.

## The fix

**One function change in `~/.zshrc` (lines 445-451)**: detect `$TMUX` and use `switch-client` instead of `attach-session` when already inside tmux.

`tmux switch-client -t <session>` changes which session the current client is viewing — no nesting, seamless switch.

### New `ta()` function

```zsh
ta() {
  if [[ -n "$TMUX" ]]; then
    # Already inside tmux: switch client to avoid nesting
    if [[ -n "$1" ]]; then
      tmux switch-client -t "$1"
    else
      tmux switch-client -l 2>/dev/null || tls
    fi
  else
    # Outside tmux: attach as before
    if [[ -n "$1" ]]; then
      tmux attach-session -t "$1"
    else
      tmux attach-session
    fi
  fi
}
```

### Behavior table

| Scenario | Before | After |
|---|---|---|
| Outside tmux, `ta foo` | `attach-session -t foo` | **same** |
| Outside tmux, `ta` | `attach-session` | **same** |
| Inside tmux, `ta foo` | nested tmux (bad) | `switch-client -t foo` |
| Inside tmux, `ta` | nested tmux (bad) | `switch-client -l` (last session), falls back to `tls` |
| Tab completion | session names | **unchanged** |

### Edge cases

- **Session doesn't exist**: `switch-client -t nonexistent` prints `can't find session: nonexistent` to stderr — same UX as the old `attach-session` failure.
- **No argument, inside tmux**: `switch-client -l` toggles to the last-used session. If there's no "last" (only one session exists), falls back to `tls` so Louis can pick one.
- **Tab completion** (`_ta` / `compdef`): untouched — it only calls `tmux list-sessions`, doesn't depend on attach vs switch.

## Files to modify

- `/home/ezalos/.zshrc` — replace `ta()` function body (lines 445-451)
- `/home/ezalos/Setup/dotfiles/.tmux.conf` — no change needed

## Verification

1. `source ~/.zshrc` to reload
2. Inside tmux: `ta <other-session>` should switch without nesting
3. Inside tmux: `ta` with no args should toggle to last session or show `tls`
4. Outside tmux (if testable): `ta <session>` should attach normally
