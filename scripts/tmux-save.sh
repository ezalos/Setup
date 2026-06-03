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

# Tools installed under the user prefix (notably `rip`) must resolve even when
# this script runs from cron or the systemd shutdown unit, whose PATH is minimal
# (`/usr/bin:/bin`). Without this, every non-interactive save died at
# `rip: command not found` and nothing was ever saved.
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SAVE_DIR="${TMUX_SAVE_DIR:-$HOME/.tmux-save}"
SAVE_LOG="${TMUX_SAVE_LOG:-$HOME/.tmux-save.log}"
STAGING_DIR="${SAVE_DIR}.staging"

# Bail BEFORE touching the existing save if there is nothing to capture. Wiping
# the old snapshot first (the previous behaviour) meant a run with no server -
# e.g. a cron tick or the shutdown unit firing while tmux was already down -
# destroyed the last good save and wrote nothing in its place.
if ! tmux list-sessions &>/dev/null; then
  echo "No tmux server running."
  exit 1
fi

# Build the new snapshot in a staging dir, then swap it into place only once it
# is complete (see end of script). A failure partway through therefore leaves
# the previous good save untouched.
[[ -d "$STAGING_DIR" ]] && rip "$STAGING_DIR"
mkdir -p "$STAGING_DIR/pane_contents"

# Skip sessions whose names contain characters that will break tmux target
# parsing or are clearly unresolved template variables (e.g. VS Code's
# ${workspaceFolder}).
is_bad_session_name() {
  [[ "$1" =~ [\$\\\{\}] ]]
}

# Save each session → window → pane
tmux list-sessions -F '#{session_name}' | while read -r session; do
  if is_bad_session_name "$session"; then
    echo "  SKIP (bad name): $session"
    continue
  fi
  tmux list-windows -t "$session" -F '#{window_index}|#{window_name}|#{window_layout}|#{window_active}' \
  | while IFS='|' read -r win_idx win_name win_layout win_active; do
    tmux list-panes -t "$session:$win_idx" \
      -F '#{pane_index}|#{pane_current_path}|#{pane_pid}' \
    | while IFS='|' read -r pane_idx pane_dir pane_pid; do
      # Detect Claude Code via session process group
      is_claude=0
      claude_session_id=""
      if ps -o comm= -g "$pane_pid" 2>/dev/null | grep -q 'claude'; then
        is_claude=1
        # Extract the Claude session ID from the child claude process
        claude_pid=$(ps -o pid=,comm= --ppid "$pane_pid" 2>/dev/null \
          | awk '$2 == "claude" {print $1; exit}')
        if [[ -n "$claude_pid" && -f "$HOME/.claude/sessions/$claude_pid.json" ]]; then
          claude_session_id=$(python3 -c \
            "import json; print(json.load(open('$HOME/.claude/sessions/$claude_pid.json'))['sessionId'])" \
            2>/dev/null || true)
        fi
      fi

      # Write metadata line (9 columns: session, win_idx, win_name, win_layout,
      #   pane_idx, pane_dir, is_claude, win_active, claude_session_id)
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$session" "$win_idx" "$win_name" "$win_layout" \
        "$pane_idx" "$pane_dir" "$is_claude" "$win_active" "$claude_session_id" \
        >> "$STAGING_DIR/state.tsv"

      # Capture scrollback (last 10k lines)
      # Sanitize session name for safe filenames (sessions can contain slashes)
      safe_session="${session//\//__}"
      tmux capture-pane -t "$session:$win_idx.$pane_idx" -p -S -10000 \
        > "$STAGING_DIR/pane_contents/${safe_session}_${win_idx}_${pane_idx}.txt" 2>/dev/null
    done
  done
done

date '+%Y-%m-%d %H:%M:%S' > "$STAGING_DIR/saved_at"

# Snapshot is complete: swap it into place. The previous save goes to the
# graveyard (recoverable via `rip --unbury`) only now that a full new one exists.
[[ -d "$SAVE_DIR" ]] && rip "$SAVE_DIR"
mv "$STAGING_DIR" "$SAVE_DIR"

# Summary
if [[ -f "$SAVE_DIR/state.tsv" ]]; then
  total_panes=$(wc -l < "$SAVE_DIR/state.tsv")
  total_sessions=$(cut -f1 "$SAVE_DIR/state.tsv" | sort -u | wc -l)
  claude_panes=$(awk -F'\t' '$7 == 1' "$SAVE_DIR/state.tsv" | wc -l)
  summary="Saved $total_panes pane(s) across $total_sessions session(s) ($claude_panes with Claude Code)"
  echo "$summary"
else
  summary="No panes found to save."
  echo "$summary"
fi

# Append to persistent log (lives outside the save dir, so it survives the swap)
printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$summary" >> "$SAVE_LOG"
# Keep only last 100 lines
tail -n 100 "$SAVE_LOG" > "$SAVE_LOG.tmp" && mv "$SAVE_LOG.tmp" "$SAVE_LOG"
