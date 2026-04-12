#!/usr/bin/env bash
# ABOUTME: Background script to check ~/Setup git sync status against remote.
# ABOUTME: Writes result to ~/.cache/dotfiles_sync_status, rate-limited to 30min globally via flock.

CACHE_FILE="${HOME}/.cache/dotfiles_sync_status"
LOCK_FILE="${HOME}/.cache/dotfiles_sync.lock"
SETUP_DIR="${HOME}/Setup"
MAX_AGE=1800  # 30 minutes in seconds

mkdir -p "${HOME}/.cache"

# Fast path: if cache is fresh, exit immediately (~1ms cost)
if [[ -f "$CACHE_FILE" ]]; then
  file_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  (( file_age < MAX_AGE )) && exit 0
fi

# Acquire lock (non-blocking — if another session is already fetching, just exit)
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# Double-check mtime after acquiring lock (another session may have just finished)
if [[ -f "$CACHE_FILE" ]]; then
  file_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
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
