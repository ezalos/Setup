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

# Session names with these characters break tmux target parsing or are
# unresolved template variables (e.g. VS Code's ${workspaceFolder}).
is_bad_session_name() {
  [[ "$1" =~ [\$\\\{\}] ]]
}

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
    if is_bad_session_name "$session"; then
      echo "  SKIP: session '$session' has invalid characters"
      skip_session="$session"
      prev_session="$session"
      continue
    fi
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

# --- Claude session verification helpers ---

# Convert a working directory to Claude's project dir path
claude_project_dir() {
  local wdir="$1"
  # Claude encodes paths: /home/ezalos/foo → -home-ezalos-foo
  local encoded="${wdir//\//-}"
  encoded="${encoded#-}"  # strip leading dash
  echo "$HOME/.claude/projects/-${encoded}"
}

# Find the N most recent session IDs in a Claude project dir, excluding already-assigned ones
# Usage: find_recent_sessions <project_dir> <count> <exclude_list_var>
# Prints session IDs one per line, most recent first
find_recent_sessions() {
  local proj_dir="$1" count="$2"
  shift 2
  local excludes=("$@")
  [[ -d "$proj_dir" ]] || return 1
  local results=()
  while IFS= read -r fpath; do
    local candidate
    candidate=$(basename "$fpath" .jsonl)
    # Skip if already assigned
    local skip=0
    for ex in "${excludes[@]}"; do
      [[ "$candidate" == "$ex" ]] && { skip=1; break; }
    done
    (( skip )) && continue
    results+=("$candidate")
    (( ${#results[@]} >= count )) && break
  done < <(ls -t "$proj_dir"/*.jsonl 2>/dev/null)
  printf '%s\n' "${results[@]}"
}

# Interactive Claude Code resumption
assigned_sessions=()

if [[ ${#claude_resume_list[@]} -gt 0 ]]; then
  echo ""
  echo "${#claude_resume_list[@]} pane(s) had Claude Code running:"
  for entry in "${claude_resume_list[@]}"; do
    target="${entry%%|*}"
    rest="${entry#*|}"
    dir="${rest%%|*}"
    sid="${rest#*|}"
    echo ""

    # Verify saved session ID against what's on disk
    proj_dir=$(claude_project_dir "$dir")
    latest_sid=""
    saved_exists=0
    saved_stale=0

    if [[ -d "$proj_dir" ]]; then
      latest_sid=$(find_recent_sessions "$proj_dir" 1 "${assigned_sessions[@]}")
      if [[ -n "$sid" && -f "$proj_dir/${sid}.jsonl" ]]; then
        saved_exists=1
        # Check if there's a newer session
        if [[ -n "$latest_sid" && "$latest_sid" != "$sid" ]]; then
          saved_stale=1
        fi
      fi
    fi

    if [[ -n "$sid" && "$saved_exists" -eq 1 && "$saved_stale" -eq 0 ]]; then
      # Saved session exists and is the latest — straightforward resume
      echo "  $target  ($dir)  [session: ${sid:0:8}…]"
      read -rp "  Resume claude --resume $sid? [y/N] " answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        tmux send-keys -t "$target" "claude --resume '$sid'" Enter
        assigned_sessions+=("$sid")
        echo "  → Resumed"
      else
        echo "  → Skipped"
      fi

    elif [[ -n "$sid" && "$saved_exists" -eq 1 && "$saved_stale" -eq 1 ]]; then
      # Saved session exists but a newer one is available
      echo "  $target  ($dir)"
      echo "    saved:  ${sid:0:8}…  (from tsave snapshot)"
      echo "    latest: ${latest_sid:0:8}…  (most recent on disk)"
      echo "  Options: [s]aved / [l]atest / [p]icker / [N]one"
      read -rp "  Choice: " answer
      case "$answer" in
        s|S)
          tmux send-keys -t "$target" "claude --resume '$sid'" Enter
          assigned_sessions+=("$sid")
          echo "  → Resumed saved session"
          ;;
        l|L)
          tmux send-keys -t "$target" "claude --resume '$latest_sid'" Enter
          assigned_sessions+=("$latest_sid")
          echo "  → Resumed latest session"
          ;;
        p|P)
          tmux send-keys -t "$target" "claude --resume" Enter
          echo "  → Opened interactive picker"
          ;;
        *)
          echo "  → Skipped"
          ;;
      esac

    elif [[ -n "$latest_sid" ]]; then
      # Saved session missing or unknown, but we found a recent one on disk
      if [[ -n "$sid" ]]; then
        echo "  $target  ($dir)  [saved session ${sid:0:8}… not found on disk]"
      else
        echo "  $target  ($dir)  [session ID was not captured]"
      fi
      echo "    latest on disk: ${latest_sid:0:8}…"
      echo "  Options: [l]atest / [p]icker / [N]one"
      read -rp "  Choice: " answer
      case "$answer" in
        l|L)
          tmux send-keys -t "$target" "claude --resume '$latest_sid'" Enter
          assigned_sessions+=("$latest_sid")
          echo "  → Resumed latest session"
          ;;
        p|P)
          tmux send-keys -t "$target" "claude --resume" Enter
          echo "  → Opened interactive picker"
          ;;
        *)
          echo "  → Skipped"
          ;;
      esac

    else
      # No session info at all
      echo "  $target  ($dir)  [no session data found]"
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
