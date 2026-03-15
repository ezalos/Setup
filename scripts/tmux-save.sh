#!/usr/bin/env bash
# ABOUTME: Save all tmux sessions, windows, panes, and working directories to disk.
# ABOUTME: Detects active Claude Code sessions for automatic resumption after reboot.

set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: tsave [-h]

Save all tmux sessions to ~/.tmux-save/ (run before reboot).
Restore with: trestore [-c LINES]
EOF
  exit 0
fi

SAVE_DIR="$HOME/.tmux-save"

# Clear previous save
[[ -d "$SAVE_DIR" ]] && rip "$SAVE_DIR"
mkdir -p "$SAVE_DIR/pane_contents"

# Bail if tmux isn't running
if ! tmux list-sessions &>/dev/null; then
  echo "No tmux server running."
  exit 1
fi

# Save each session → window → pane
tmux list-sessions -F '#{session_name}' | while read -r session; do
  tmux list-windows -t "$session" -F '#{window_index}|#{window_name}|#{window_layout}|#{window_active}' \
  | while IFS='|' read -r win_idx win_name win_layout win_active; do
    tmux list-panes -t "$session:$win_idx" \
      -F '#{pane_index}|#{pane_current_path}|#{pane_pid}' \
    | while IFS='|' read -r pane_idx pane_dir pane_pid; do
      # Detect Claude Code via session process group
      is_claude=0
      if ps -o comm= -g "$pane_pid" 2>/dev/null | grep -q 'claude'; then
        is_claude=1
      fi

      # Write metadata line
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$session" "$win_idx" "$win_name" "$win_layout" \
        "$pane_idx" "$pane_dir" "$is_claude" "$win_active" \
        >> "$SAVE_DIR/state.tsv"

      # Capture scrollback (last 10k lines)
      # Sanitize session name for safe filenames (sessions can contain slashes)
      safe_session="${session//\//__}"
      tmux capture-pane -t "$session:$win_idx.$pane_idx" -p -S -10000 \
        > "$SAVE_DIR/pane_contents/${safe_session}_${win_idx}_${pane_idx}.txt" 2>/dev/null
    done
  done
done

date '+%Y-%m-%d %H:%M:%S' > "$SAVE_DIR/saved_at"

# Summary
if [[ -f "$SAVE_DIR/state.tsv" ]]; then
  total_panes=$(wc -l < "$SAVE_DIR/state.tsv")
  total_sessions=$(cut -f1 "$SAVE_DIR/state.tsv" | sort -u | wc -l)
  claude_panes=$(awk -F'\t' '$7 == 1' "$SAVE_DIR/state.tsv" | wc -l)
  echo "Saved $total_panes pane(s) across $total_sessions session(s) ($claude_panes with Claude Code)"
else
  echo "No panes found to save."
fi
