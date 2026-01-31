#!/usr/bin/env bash
# ---------------------------------------------------------------------------- #
#  setup_helpers.sh                                                            #
# ---------------------------------------------------------------------------- #
# Miscellaneous shell helper functions that were previously embedded in the   #
# .zshrc file. They are now factored out for clarity and maintainability.     #
# This file is meant to be *sourced* by the shell, not executed.              #
# ---------------------------------------------------------------------------- #

# ----------------------------------------------------------------- git sync --
function setup_sync_up() {
    local current_dir=$(pwd)
    local commit_msg="$1"

    cd "$PATH_SETUP_DIR" || { echo "❌ Failed to change to setup directory"; return 1; }

    echo "\n🔍 Fetching updates..."
    git fetch || { echo "❌ Failed to fetch updates"; cd "$current_dir"; return 1; }

    echo "\n📁 Adding dotfiles..."
    git add dotfiles || { echo "❌ Failed to add dotfiles"; cd "$current_dir"; return 1; }

    echo "\n📊 Current status:"
    git status

    echo "\n❓ Proceed with commit and push? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        local full_msg="dot: ${commit_msg:-syncing dotfiles} from device [$WHICH_COMPUTER]"
        git commit -m "$full_msg" || { echo "❌ Failed to commit"; cd "$current_dir"; return 1; }

        echo "\n⬆️  Pushing changes..."
        git push || { echo "❌ Failed to push changes"; cd "$current_dir"; return 1; }

        echo "\n✅ Successfully synced up!"
    else
        echo "\n⚠️  Sync cancelled"
    fi

    cd "$current_dir"
}

function setup_sync_down() {
    local current_dir=$(pwd)

    cd "$PATH_SETUP_DIR" || { echo "❌ Failed to change to setup directory"; return 1; }

    echo "\n⬇️  Pulling updates..."
    if git pull; then
        echo "\n✅ Successfully pulled updates"
        cd "$current_dir"
        echo "\n🔄 Reloading shell configuration..."
        source "$HOME/.zshrc"
    else
        echo "❌ Failed to pull updates"
        cd "$current_dir"
        return 1
    fi
}

# -------------------------------------------------------------- rnd_free_space --
function rnd_free_space() {
    echo "Cleaning up old files in /srv/data/datasets/octopus_images/crop/..."
    find /srv/data/datasets/octopus_images/crop/. -maxdepth 1 -type f -ctime +3 -print0 | xargs -0 rm -v
    echo "Cleaning up old files in /srv/data/datasets/octopus_images/..."
    find /srv/data/datasets/octopus_images/. -maxdepth 1 -type f -ctime +3 -print0 | xargs -0 rm -v
    echo "Cleanup completed!"
}

# -------------------------------------------------------------- rsync helpers ----
function rsync_monorepo() {
    local target_dir="${2:-monorepo}"
    local remote_dir="${3:-monorepo}"
    rsync -ravh \
        --exclude='env' \
        --exclude='.python-version' \
        --exclude='.venv' \
        --exclude='.osgrep/lancedb' \
        --exclude='**/.venv' \
        --exclude='venv' \
        --exclude='**/venv' \
        --exclude='.git/*' \
        --exclude='*.pyc' \
        --exclude='__pycache__' \
        --exclude='.pytest_cache' \
        --exclude='.ipynb_checkpoint' \
        --exclude='untracked_files/data/*' \
        "$HOME/$target_dir/" \
        "$1:$remote_dir/"
}

function b_rsync_monorepo() {
    local target_dir="${2:-monorepo}"
    local remote_dir="${3:-monorepo}"
    rsync -ravh \
        --exclude='env' \
        --exclude='.python-version' \
        --exclude='.venv' \
        --exclude='.osgrep/lancedb' \
        --exclude='**/.venv' \
        --exclude='venv' \
        --exclude='**/venv' \
        --exclude='.git/*' \
        --exclude='*.pyc' \
        --exclude='__pycache__' \
        --exclude='.pytest_cache' \
        --exclude='.ipynb_checkpoint' \
        --exclude='untracked_files/data/*' \
        "$1:$remote_dir/" \
        "$HOME/$target_dir/"
}

# ------------------------------------------------------------ mkenv helpers ----

# mkenv_pip --------------------------------------------------
function mkenv_pip() {
    cat > .envrc << EOF
#!$(command -v bash)

source ./venv/bin/activate

unset PS1
EOF

    if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
        python -m venv venv && direnv allow
    elif [[ $WHICH_COMPUTER == "MacBook" ]] || [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
        python3 -m venv venv && direnv allow
    fi
}

# mkenv_conda ------------------------------------------------
function mkenv_conda() {
    cat > .envrc << EOF
#!$(command -v bash)

eval "\$(conda shell.bash hook)"

conda activate ${PWD##*/}

unset PS1
EOF
    conda create -n ${PWD##*/} python=3.10 -y && direnv allow
}

# mkenv_uv ---------------------------------------------------
function mkenv_uv() {
    local DIR_FOR_VENV=".venv"
    cat > .envrc << EOF
#!$(command -v bash)

if [ -f "$DIR_FOR_VENV/bin/activate" ]; then
    source "$DIR_FOR_VENV/bin/activate"
    export VIRTUAL_ENV="\$(pwd)/$DIR_FOR_VENV"
else
    echo "Warning: $DIR_FOR_VENV/bin/activate not found. Did you run 'uv venv'?"
fi

unset PS1
EOF
    uv venv && direnv allow && uv init
}

# Default alias ----------------------------------------------
alias mkenv='mkenv_uv'
