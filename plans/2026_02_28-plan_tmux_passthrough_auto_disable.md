# Plan: Auto-disable passthrough when inner tmux detaches

## Context

Louis uses tmux nested over SSH (local tmux → SSH → remote tmux). We added F12 passthrough toggle so `C-a` goes directly to the inner tmux. Problem: when inner tmux detaches/is killed, the outer tmux stays in passthrough mode — Louis must remember to press F12 manually. He wants it to auto-deactivate.

**Key constraint:** The outer tmux (local) and inner tmux (remote) are on different machines. The outer tmux cannot directly observe inner tmux events.

**Solution:** Use a terminal title escape sequence as a cross-machine signal. When `ta`'s `tmux attach-session` returns (inner tmux detached/killed), the `ta` function sends a special pane title. This propagates through SSH to the outer tmux pane. The outer tmux's `pane-title-changed` hook detects it and auto-disables passthrough.

## Mechanism

```
Inner tmux detaches
  → tmux attach-session returns in ta()
  → ta() prints: \e]2;__PASSTHROUGH_OFF__\a  (set pane title)
  → escape sequence travels through SSH to outer tmux pane
  → outer tmux fires pane-title-changed hook
  → hook checks: key_table==off AND pane_title==__PASSTHROUGH_OFF__
  → if yes: restore prefix, key-table, status-style
```

## Changes

### 1. `/home/ezalos/.zshrc` — `ta()` function (~line 445)

Replace the echo reminder with a pane title signal:

```zsh
ta() {
  if [[ -n "$1" ]]; then
    if tmux switch-client -t "$1" 2>/dev/null; then
      return 0
    fi
    tmux attach-session -t "$1"
    # Signal outer tmux to disable passthrough via pane title
    if [[ -n "$TMUX" ]]; then
      printf '\e]2;__PASSTHROUGH_OFF__\a'
    fi
  else
    if [[ -n "$TMUX" ]]; then
      tmux switch-client -l 2>/dev/null || tls
    else
      tmux attach-session
    fi
  fi
}
```

### 2. `/home/ezalos/Setup/dotfiles/.tmux.conf` — nested tmux section (~line 129)

Add `pane-title-changed` hook alongside existing hooks:

```tmux
# Auto-disable passthrough when inner tmux signals via pane title
set-hook -g pane-title-changed 'if -F "#{&&:#{==:#{client_key_table},off},#{==:#{pane_title},__PASSTHROUGH_OFF__}}" "set -u prefix; set -u key-table; set -u status-style; refresh-client -S" ""'
```

Keep the existing `pane-exited` and `pane-died` hooks (they handle SSH connection dropping).

## Behavior table

| Scenario | What happens |
|---|---|
| F12 pressed, inner tmux detaches | `ta` sends title signal → hook auto-disables passthrough |
| F12 pressed, SSH connection drops | `pane-exited`/`pane-died` hook auto-disables passthrough |
| F12 pressed, manual F12 again | Manual toggle still works as before |
| F12 not pressed, inner tmux detaches | Title signal sent, but hook condition (`key_table==off`) is false → no-op |
| Local session switch (`ta foo`) | `switch-client` succeeds → no nesting, no signal needed |

## Edge cases

- **`allow-rename off`** (line 32): This controls window renaming, not pane titles. Pane titles set via `\e]2;...\a` are unaffected.
- **Hook recursion**: After the hook resets passthrough, the pane title is still `__PASSTHROUGH_OFF__`. But the hook checks `key_table==off`, which is now false (we just reset it). No infinite loop.
- **Title lingers**: The pane title stays as `__PASSTHROUGH_OFF__` until the next title change. This is cosmetic and harmless (pane title isn't displayed by default in Louis's config).

## Verification

1. `source ~/.zshrc` and `C-a r` to reload both configs
2. SSH to remote → `ta session` → press F12 (status bar turns red)
3. Detach inner tmux (`C-a d`) → status bar should auto-return to normal (blue)
4. Verify outer tmux prefix works (`C-a w` shows window list)
5. Test SSH close: connect, F12, kill SSH → passthrough should auto-disable
6. Test local switch: `ta other-local-session` → should use switch-client, no nesting
