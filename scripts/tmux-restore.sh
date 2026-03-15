#!/usr/bin/env bash
# ABOUTME: Restore tmux sessions from a previous tsave snapshot.
# ABOUTME: Recreates sessions, windows, panes, layouts, and optionally resumes Claude Code.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: trestore [-c LINES] [-h]

Restore tmux sessions from a previous tsave snapshot.

Options:
  -c LINES   Number of scrollback context lines per pane (default: 25, 0 to disable)
  -h         Show this help
EOF
  exit 0
}

SAVE_DIR="$HOME/.tmux-save"
STATE="$SAVE_DIR/state.tsv"
CONTEXT_LINES=25

while getopts ":c:h" opt; do
  case "$opt" in
    c) CONTEXT_LINES="$OPTARG" ;;
    h) usage ;;
    *) echo "Unknown option: -$OPTARG"; usage ;;
  esac
done

if [[ ! -f "$STATE" ]]; then
  echo "No saved state found. Run tsave first."
  exit 1
fi

# Show the tail of saved scrollback in a pane for context
show_pane_context() {
  local target="$1" session="$2" win_idx="$3" pane_idx="$4"
  (( CONTEXT_LINES > 0 )) || return 0
  local safe_session="${session//\//__}"
  local scrollback="$SAVE_DIR/pane_contents/${safe_session}_${win_idx}_${pane_idx}.txt"
  [[ -f "$scrollback" ]] || return 0
  # Strip trailing blank lines (tmux capture includes empty pane area), then tail
  tmux send-keys -t "$target" \
    "echo '── saved scrollback ──' && sed -e :a -e '/^[[:space:]]*\$/{\$d;N;ba' -e '}' '$scrollback' | tail -n $CONTEXT_LINES && echo '─────────────────────'" Enter
}

echo "Restoring from $(cat "$SAVE_DIR/saved_at")..."

prev_session=""
prev_win=""
skip_session=""
first_win_of_session=""
pane_created_count=0
active_windows=()
claude_resume_list=()

while IFS=$'\t' read -r session win_idx win_name win_layout pane_idx pane_dir is_claude win_active claude_session_id; do

  # Skip all lines belonging to a session we couldn't create or already exists
  [[ "$session" == "$skip_session" ]] && continue

  # --- New session ---
  if [[ "$session" != "$prev_session" ]]; then
    skip_session=""
    if tmux has-session -t "$session" 2>/dev/null; then
      echo "  SKIP: session '$session' already exists"
      skip_session="$session"
      prev_session="$session"
      continue
    fi

    if ! tmux new-session -d -s "$session" -c "$pane_dir" 2>/dev/null; then
      echo "  SKIP: cannot create session '$session' (invalid name?)"
      skip_session="$session"
      prev_session="$session"
      continue
    fi

    # Move the auto-created window to the correct index if it differs
    auto_win_idx=$(tmux list-windows -t "$session" -F '#{window_index}' | head -1)
    if [[ "$auto_win_idx" != "$win_idx" ]]; then
      tmux move-window -s "$session:$auto_win_idx" -t "$session:$win_idx"
    fi
    tmux rename-window -t "$session:$win_idx" "$win_name"

    first_win_of_session="$win_idx"
    prev_session="$session"
    prev_win="$win_idx"
    pane_created_count=1

    # First pane was created with the session — position it
    tmux send-keys -t "$session:$win_idx.$pane_idx" "cd '${pane_dir}' && clear" Enter
    show_pane_context "$session:$win_idx.$pane_idx" "$session" "$win_idx" "$pane_idx"

    [[ "$win_active" == "1" ]] && active_windows+=("$session:$win_idx")
    [[ "$is_claude" == "1" ]] && claude_resume_list+=("$session:$win_idx.$pane_idx|$pane_dir|${claude_session_id:-}")

    tmux select-layout -t "$session:$win_idx" "$win_layout" 2>/dev/null
    continue
  fi

  # --- New window within existing session ---
  if [[ "$win_idx" != "$prev_win" ]]; then
    tmux new-window -t "$session:$win_idx" -n "$win_name" -c "$pane_dir"
    prev_win="$win_idx"
    pane_created_count=1

    [[ "$win_active" == "1" ]] && active_windows+=("$session:$win_idx")
  else
    # --- Additional pane (split) within current window ---
    tmux split-window -t "$session:$win_idx" -c "$pane_dir"
    pane_created_count=$((pane_created_count + 1))
  fi

  # Position the pane
  tmux send-keys -t "$session:$win_idx.$pane_idx" "cd '${pane_dir}' && clear" Enter
  show_pane_context "$session:$win_idx.$pane_idx" "$session" "$win_idx" "$pane_idx"

  [[ "$is_claude" == "1" ]] && claude_resume_list+=("$session:$win_idx.$pane_idx|$pane_dir|${claude_session_id:-}")

  # Reapply layout after each pane so geometry stays correct
  tmux select-layout -t "$session:$win_idx" "$win_layout" 2>/dev/null

done < "$STATE"

# Select the window that was active in each session
if [[ ${#active_windows[@]} -gt 0 ]]; then
  for aw in "${active_windows[@]}"; do
    tmux select-window -t "$aw" 2>/dev/null
  done
fi

# Summary
total_sessions=$(cut -f1 "$STATE" | sort -u | wc -l)
echo "Restored $total_sessions session(s)."
echo "Scrollback captures available in: $SAVE_DIR/pane_contents/"

# Interactive Claude Code resumption
if [[ ${#claude_resume_list[@]} -gt 0 ]]; then
  echo ""
  echo "${#claude_resume_list[@]} pane(s) had Claude Code running:"
  for entry in "${claude_resume_list[@]}"; do
    target="${entry%%|*}"
    rest="${entry#*|}"
    dir="${rest%%|*}"
    sid="${rest#*|}"
    echo ""
    if [[ -n "$sid" ]]; then
      echo "  $target  ($dir)  [session: ${sid:0:8}…]"
      read -rp "  Resume claude --resume $sid? [y/N] " answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        tmux send-keys -t "$target" "claude --resume '$sid'" Enter
        echo "  → Resumed (specific session)"
      else
        echo "  → Skipped"
      fi
    else
      echo "  $target  ($dir)  [session ID unknown]"
      read -rp "  Resume claude --resume (interactive picker)? [y/N] " answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        tmux send-keys -t "$target" "claude --resume" Enter
        echo "  → Opened interactive picker"
      else
        echo "  → Skipped"
      fi
    fi
  done
fi
