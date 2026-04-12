#!/usr/bin/env bash
# ABOUTME: Background script to check ~/Setup git sync status against remote.
# ABOUTME: Writes result to ~/.cache/dotfiles_sync_status, rate-limited to 30min globally via flock.

CACHE_FILE="${HOME}/.cache/dotfiles_sync_status"
LOCK_DIR="${HOME}/.cache/dotfiles_sync.lock.d"
SETUP_DIR="${HOME}/Setup"
MAX_AGE=1800  # 30 minutes in seconds

mkdir -p "${HOME}/.cache"

# Portable mtime. GNU stat must come first: on Linux, "stat -f" means
# "filesystem info" (succeeds with wrong output), while "stat -c" fails
# cleanly on macOS. BSD stat on macOS uses "-f <format>".
get_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# Fast path: if cache is fresh, exit immediately (~1ms cost)
if [[ -f "$CACHE_FILE" ]]; then
  file_age=$(( $(date +%s) - $(get_mtime "$CACHE_FILE") ))
  (( file_age < MAX_AGE )) && exit 0
fi

# Acquire lock via atomic mkdir (portable; no flock dependency)
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0  # another session is already fetching
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# Double-check mtime after acquiring lock (another session may have just finished)
if [[ -f "$CACHE_FILE" ]]; then
  file_age=$(( $(date +%s) - $(get_mtime "$CACHE_FILE") ))
  (( file_age < MAX_AGE )) && exit 0
fi

cd "$SETUP_DIR" || exit 1

# Fetch remote state (the only network call)
git fetch --quiet 2>/dev/null

# Compute sync status
local_head=$(git rev-parse HEAD 2>/dev/null)
remote_head=$(git rev-parse @{u} 2>/dev/null)
merge_base=$(git merge-base HEAD @{u} 2>/dev/null)
dirty=$(git status --porcelain 2>/dev/null | head -1)

status=""
[[ -n "$dirty" ]] && status="dirty"

if [[ -n "$remote_head" && "$local_head" != "$remote_head" ]]; then
  if [[ "$local_head" == "$merge_base" ]]; then
    status="${status:+$status }behind"
  elif [[ "$remote_head" == "$merge_base" ]]; then
    status="${status:+$status }ahead"
  else
    status="${status:+$status }diverged"
  fi
fi

echo "${status:-ok}" > "$CACHE_FILE"
