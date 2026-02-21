# ---------------------------------------------------------------------------- #
#                                     PATH                                     #
# ---------------------------------------------------------------------------- #


# Check if CURSOR_AGENT is set and return early if it is
if [[ -n "$CURSOR_AGENT" ]]; then
    export WHICH_COMPUTER="CURSOR_AGENT"
fi



export PATH_SETUP_DIR="$HOME/Setup"
# Helper utilities ---------------------------------------------------- #
# Functions to safely add directories to $PATH (duplicates removed)
path_prepend() { for d in "$@"; do [[ -d $d ]] && path=($d $path); done }
path_append()  { for d in "$@"; do [[ -d $d ]] && path=($path $d); done }
typeset -gU path

# Sensible zsh options ------------------------------------------------ #
setopt autocd pushd_ignore_dups share_history hist_ignore_space inc_append_history 
# zmodload zsh/zprof

# Initial PATH bootstrap
path_prepend "$PATH_SETUP_DIR/bin" "$PATH_SETUP_DIR/usr/bin" "$HOME/.local/bin"

if [[ "$WHICH_COMPUTER" == "CURSOR_AGENT" ]]; then
export ZSH_THEME=""
else
# From: https://github.com/romkatv/powerlevel10k/issues/702#issuecomment-626222730
emulate zsh -c "$(direnv export zsh)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# From: https://github.com/romkatv/powerlevel10k/issues/702#issuecomment-626222730
emulate zsh -c "$(direnv hook zsh)"

ZSH_THEME="powerlevel10k/powerlevel10k"
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    .zshrc                                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: ezalos <ezalos@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#                                                      #+#    #+#              #
#    Created: 2021/03/27 23:02:39 by ezalos           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# ---------------------------------------------------------------------------- #
#                                   Oh-my-zsh                                  #
# ---------------------------------------------------------------------------- #
# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

source $ZSH/custom/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)
source $ZSH/oh-my-zsh.sh
HISTCONTROL=ignorespace
export LANG=en_US.UTF-8

# BINDKEYS
bindkey '^[[1;2A' history-substring-search-up
bindkey '^[[1;2B' history-substring-search-down
# ---------------------------------------------------------------------------- #
#                                     Init                                     #
# ---------------------------------------------------------------------------- #

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
else
   export EDITOR='nvim'
fi


# ---------------------------------------------------------------------------- #
#                                 Environment file                             #
# ---------------------------------------------------------------------------- #
SETUP_ENV_FILE="$PATH_SETUP_DIR/.setup_env"

# Load persisted WHICH_COMPUTER if present
if [[ -f "$SETUP_ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SETUP_ENV_FILE"
fi

# Set computer identifier
if [[ -z "${WHICH_COMPUTER:-}" ]]; then
    if [[ `uname -n` = "ezalos-TM1704" ]]; then
        export WHICH_COMPUTER="TheBeast"
    elif [[ `uname -n` = "TheBeast" ]]; then
        export WHICH_COMPUTER="TheBeast"
    elif [[ `uname -n` = "TinyButMighty" ]]; then
        export WHICH_COMPUTER="TinyButMighty"
    elif [[ `uname -n` = "Louiss-MBP.lan" ]]; then
        export WHICH_COMPUTER="MacBook"
    elif [[ `uname -n` = "Louiss-MacBook-Pro.local" ]]; then
        export WHICH_COMPUTER="MacBook"
    elif [[ `uname -n` =~ ^louiss-macbook-pro-[0-9]+\.home$ ]]; then
        export WHICH_COMPUTER="MacBook"
    elif [[ `uname -n` =~ ^Louiss-MacBook-Pro-[0-9]+\.local$ ]]; then
        export WHICH_COMPUTER="MacBook"
    elif [[ `uname -n` = "MacBook-Pro-de-Louis.local" ]] || [[ `uname -n` = "mbp-de-louis.home" ]]; then
        export WHICH_COMPUTER="MacBook_Heuritech" # Macbook from Heuritech
    elif [[ `uname -n` =~ ^rnd ]]; then
        export WHICH_COMPUTER="rnd_Heuritech" # Remote Heuritech machine
    elif [[ `uname -n` = "smic" ]]; then
        export WHICH_COMPUTER="smic_Heuritech" # Remote Heuritech machine
    else
        export WHICH_COMPUTER="Unknown"
    fi

    export WHICH_COMPUTER

    # Persist only if recognised
    if [[ $WHICH_COMPUTER != "Unknown" ]]; then
        if [[ ! -f "$SETUP_ENV_FILE" ]] || ! grep -q '^export WHICH_COMPUTER=' "$SETUP_ENV_FILE"; then
            echo "export WHICH_COMPUTER=\"$WHICH_COMPUTER\"" >> "$SETUP_ENV_FILE"
        fi
    fi
fi


# ---------------------------------------------------------------------------- #
#                                   SSH INIT                                   #
# ---------------------------------------------------------------------------- #
# One-shot SSH agent/key setup ----------------------------------------------- #
setup_ssh() {
  (( ${+SSH_AUTH_SOCK} )) || eval "$(ssh-agent -s)" >/dev/null 2>&1

  local key=""
  case "$WHICH_COMPUTER" in
      TheBeast)       key="$HOME/.ssh/id_ed_ghub" ;;
      TinyButMighty)  key="$HOME/.ssh/id_ed_ghub" ;;
      MacBook)        key="$HOME/.ssh/gthb" ;;
      *_Heuritech)    key="$HOME/.ssh/ghub_ezalos" ;;
  esac

  if [[ -n $key && -f $key ]]; then
      ssh-add "$key" >/dev/null 2>&1
  else
      echo >&2 "⚠️  SSH key $key not found"
  fi
}

setup_ssh


# ---------------------------------------------------------------------------- #
#                                     Conda                                    #
# ---------------------------------------------------------------------------- #

if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
    export PATH=$PATH:/home/ezalos/miniconda3/bin
	# Lazy-load conda to speed up shell startup
	lazy_conda() {
		unset -f lazy_conda
		eval "$(/home/ezalos/miniconda3/bin/conda shell.zsh hook 2> /dev/null)"
	}
	add-zsh-hook precmd lazy_conda

	# Machine-local secrets (tokens, keys) — never committed
	[[ -f "$PATH_SETUP_DIR/.secrets.sh" ]] && source "$PATH_SETUP_DIR/.secrets.sh"

	# OpenClaw aliases
	alias oc-cli='docker compose -f ~/openclaw/docker-compose.yml -f ~/openclaw/docker-compose.extra.yml run --rm openclaw-cli'
	alias oc-restart='docker compose -f ~/openclaw/docker-compose.yml -f ~/openclaw/docker-compose.extra.yml restart openclaw-gateway'
	alias oc-reload='docker compose -f ~/openclaw/docker-compose.yml -f ~/openclaw/docker-compose.extra.yml down && docker compose -f ~/openclaw/docker-compose.yml -f ~/openclaw/docker-compose.extra.yml up -d openclaw-gateway'
	alias oc-logs='docker compose -f ~/openclaw/docker-compose.yml -f ~/openclaw/docker-compose.extra.yml logs -f openclaw-gateway'
fi

# ---------------------------------------------------------------------------- #
#                                     ALIAS                                    #
# ---------------------------------------------------------------------------- #

# Helper scripts
[[ -f "$PATH_SETUP_DIR/scripts/setup_helpers.sh" ]] && source "$PATH_SETUP_DIR/scripts/setup_helpers.sh"
[[ -f "$PATH_SETUP_DIR/scripts/heuritech_env.sh" ]] && source "$PATH_SETUP_DIR/scripts/heuritech_env.sh"

# General aliases
if [[ $WHICH_COMPUTER == "TheBeast" ]] || [[ $WHICH_COMPUTER == "smic_Heuritech" ]] || [[ $WHICH_COMPUTER == "rnd_Heuritech" ]]; then
alias copy='xclip -sel c'
elif [[ $WHICH_COMPUTER == "MacBook" ]] || [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
alias copy='pbcopy'
fi

alias indent="python3 ~/42/Python_Indentation/Indent.py -f"
alias gcl="git clone"
alias ec="$EDITOR $HOME/.zshrc"
alias sc="source $HOME/.zshrc"
alias neo="neofetch --separator '\t'"
alias iscuda="python3 -c 'import sys; print(f\"{sys.version = }\"); import torch; print(f\"{torch. __version__ = }\"); print(f\"{torch.cuda.is_available() = }\"); print(f\"{torch.cuda.device_count() = }\")'"
alias bt="batcat --paging=never --style=plain "

# Docker cleanup aliases
alias docker_clean_ps='docker rm $(docker ps --filter=status=exited --filter=status=created -q)'
alias docker_clean_images='docker rmi $(docker images -a --filter=dangling=true -q)'
alias docker_clean_overlay='docker rm -vf $(docker ps --filter=status=exited --filter=status=created -q) ; docker rmi -f $(docker images --filter=dangling=true -q) ; docker volume prune -f ; docker system prune -a -f'
alias docker_kill_all='docker kill $(docker ps -a -q)'

# Convert epoch timestamp to human-readable idle string (e.g. "2d 5h", "15m")
_tmux_idle_fmt() {
  local now=$(date +%s)
  local delta=$(( now - $1 ))
  local days=$(( delta / 86400 ))
  local hours=$(( (delta % 86400) / 3600 ))
  local mins=$(( (delta % 3600) / 60 ))
  local secs=$(( delta % 60 ))
  if (( days > 0 )); then
    printf "%dd %dh" "$days" "$hours"
  elif (( hours > 0 )); then
    printf "%dh %dm" "$hours" "$mins"
  elif (( mins > 0 )); then
    printf "%dm" "$mins"
  else
    printf "%ds" "$secs"
  fi
}

# tmux session listing with idle times, sorted oldest→newest
tls() {
  tmux list-sessions &>/dev/null || { echo "No tmux sessions"; return 1; }
  echo ""
  local sorted_sessions=(${(f)"$(tmux list-sessions -F '#{session_activity}|#{session_name}' | sort -n | cut -d'|' -f2)"})
  local s attached label line idx cmd wdir activity idle
  for s in "${sorted_sessions[@]}"; do
    attached=$(tmux display-message -t "$s" -p '#{session_attached}')
    if (( attached > 0 )); then
      label="\033[32m(attached)\033[0m"
    else
      label="\033[33m(detached)\033[0m"
    fi
    printf "\033[1;36m%s\033[0m %b\n" "$s" "$label"
    for line in ${(f)"$(tmux list-windows -t "$s" -F '#{window_index}|#{pane_current_command}|#{pane_current_path}|#{window_activity}')"}; do
      idx="${line%%|*}"; line="${line#*|}"
      cmd="${line%%|*}"; line="${line#*|}"
      wdir="${line%%|*}"; line="${line#*|}"
      activity="$line"
      idle=$(_tmux_idle_fmt "$activity")
      printf "  %s: %s @ %s \033[2m(%s ago)\033[0m\n" "$idx" "$cmd" "$wdir" "$idle"
    done
  done
}

# tmux cleanup: detect phantom windows and stale sessions
tclean() {
  local stale=0 threshold_hours=72 dry_run=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stale|-s) stale=1; shift ;;
      --hours|-h) threshold_hours="$2"; shift 2 ;;
      --dry-run|-n) dry_run=1; shift ;;
      --help)
        cat <<'USAGE'
Usage: tclean [--stale|-s] [--hours N|-h N] [--dry-run|-n] [--help]

  (default)       Detect phantom windows (opened but never used)
  --stale, -s     Also detect stale detached sessions (idle beyond threshold)
  --hours N, -h N Set stale threshold in hours (default: 72)
  --dry-run, -n   Show candidates without killing anything
  --help          Show this help message
USAGE
        return 0
        ;;
      *) echo "Unknown option: $1"; return 1 ;;
    esac
  done

  tmux list-sessions &>/dev/null || { echo "No tmux sessions"; return 1; }

  # Detect current session:window to never list it
  local current_session="" current_window=""
  if [[ -n "$TMUX" ]]; then
    current_session=$(tmux display-message -p '#{session_name}')
    current_window=$(tmux display-message -p '#{window_index}')
  fi

  local -a targets reasons previews
  local -A targeted
  local count=0

  # --- Phantom detection: windows where nothing was ever typed ---
  local pline sess widx cmd hist cury
  for pline in ${(f)"$(tmux list-windows -a -F '#{session_name}|#{window_index}|#{pane_current_command}|#{history_size}|#{cursor_y}')"}; do
    sess="${pline%%|*}"; pline="${pline#*|}"
    widx="${pline%%|*}"; pline="${pline#*|}"
    cmd="${pline%%|*}"; pline="${pline#*|}"
    hist="${pline%%|*}"; pline="${pline#*|}"
    cury="$pline"

    [[ "$sess" == "$current_session" && "$widx" == "$current_window" ]] && continue
    [[ "$cmd" == zsh || "$cmd" == bash || "$cmd" == sh ]] || continue
    if (( hist == 0 && cury <= 5 )); then
      count=$((count + 1))
      targets+=("${sess}:${widx}")
      reasons+=("phantom: shell with no history, cursor at line ${cury}")
      previews+=("$(tmux capture-pane -t "${sess}:${widx}" -p 2>/dev/null | tail -5)")
      targeted["${sess}:${widx}"]=1
    fi
  done

  # --- Stale detection: detached sessions idle beyond threshold ---
  if (( stale )); then
    local -A session_total session_phantom
    local aline
    for aline in ${(f)"$(tmux list-windows -a -F '#{session_name}|#{window_index}|#{pane_current_command}|#{history_size}|#{cursor_y}')"}; do
      sess="${aline%%|*}"; aline="${aline#*|}"
      widx="${aline%%|*}"; aline="${aline#*|}"
      cmd="${aline%%|*}"; aline="${aline#*|}"
      hist="${aline%%|*}"; aline="${aline#*|}"
      cury="$aline"
      session_total[$sess]=$(( ${session_total[$sess]:-0} + 1 ))
      if [[ "$cmd" == zsh || "$cmd" == bash || "$cmd" == sh ]] && (( hist == 0 && cury <= 5 )); then
        session_phantom[$sess]=$(( ${session_phantom[$sess]:-0} + 1 ))
      fi
    done

    local now=$(date +%s)
    local threshold_secs=$(( threshold_hours * 3600 ))
    local sline attached activity idle_secs all_shell wcmd idle_str windex

    for sline in ${(f)"$(tmux list-sessions -F '#{session_name}|#{session_attached}|#{session_activity}')"}; do
      sess="${sline%%|*}"; sline="${sline#*|}"
      attached="${sline%%|*}"; sline="${sline#*|}"
      activity="$sline"

      (( attached > 0 )) && continue
      [[ "$sess" == "$current_session" ]] && continue
      # Skip sessions fully caught by phantom detection
      (( ${session_phantom[$sess]:-0} > 0 && session_phantom[$sess] == session_total[$sess] )) && continue

      idle_secs=$(( now - activity ))
      (( idle_secs < threshold_secs )) && continue

      # Check all windows are shell-only
      all_shell=1
      for wcmd in ${(f)"$(tmux list-windows -t "$sess" -F '#{pane_current_command}')"}; do
        [[ "$wcmd" == zsh || "$wcmd" == bash || "$wcmd" == sh ]] || { all_shell=0; break; }
      done
      (( all_shell )) || continue

      idle_str=$(_tmux_idle_fmt "$activity")
      for windex in ${(f)"$(tmux list-windows -t "$sess" -F '#{window_index}')"}; do
        [[ -n "${targeted[${sess}:${windex}]}" ]] && continue
        count=$((count + 1))
        targets+=("${sess}:${windex}")
        reasons+=("stale: session detached, idle ${idle_str}, all windows shell-only")
        previews+=("$(tmux capture-pane -t "${sess}:${windex}" -p 2>/dev/null | tail -5)")
        targeted["${sess}:${windex}"]=1
      done
    done
  fi

  if (( count == 0 )); then
    echo "No phantom${stale:+/stale} windows found."
    return 0
  fi

  # Display candidates
  echo "Found $count candidate(s):"
  echo ""
  local i
  for i in {1..$count}; do
    printf "\033[1;33m%3d)\033[0m \033[1m%s\033[0m — %s\n" "$i" "${targets[$i]}" "${reasons[$i]}"
    if [[ -n "${previews[$i]}" ]]; then
      printf "\033[2m%s\033[0m\n" "${previews[$i]}"
    fi
    echo ""
  done

  if (( dry_run )); then
    echo "(dry-run: no windows killed)"
    return 0
  fi

  # Interactive prompt
  printf "Kill? [y/N/numbers]: "
  local reply
  read -r reply

  local -a to_kill
  if [[ "$reply" == "y" || "$reply" == "Y" ]]; then
    to_kill=({1..$count})
  elif [[ "$reply" =~ ^[0-9] ]]; then
    to_kill=(${=reply})
  else
    echo "Aborted."
    return 0
  fi

  # Determine full-session kills vs individual window kills
  local -A sess_kill_n sess_win_n
  local t s
  for i in "${to_kill[@]}"; do
    (( i >= 1 && i <= count )) || continue
    t="${targets[$i]}"
    s="${t%%:*}"
    sess_kill_n[$s]=$(( ${sess_kill_n[$s]:-0} + 1 ))
  done
  for s in "${(@k)sess_kill_n}"; do
    sess_win_n[$s]=$(tmux list-windows -t "$s" 2>/dev/null | wc -l | tr -d ' ')
  done

  local killed=0
  local -A already_killed
  for i in "${to_kill[@]}"; do
    (( i >= 1 && i <= count )) || continue
    t="${targets[$i]}"
    s="${t%%:*}"
    if (( sess_kill_n[$s] >= sess_win_n[$s] )); then
      # All windows of this session selected — kill entire session
      if (( ! ${already_killed[$s]:-0} )); then
        tmux kill-session -t "$s" 2>/dev/null && {
          printf "  Killed session \033[1m%s\033[0m\n" "$s"
          killed=$((killed + 1))
        }
        already_killed[$s]=1
      fi
    else
      tmux kill-window -t "$t" 2>/dev/null && {
        printf "  Killed window \033[1m%s\033[0m\n" "$t"
        killed=$((killed + 1))
      }
    fi
  done
  echo "Killed $killed target(s)."
}

# tmux helpers: create, attach
tn() { tmux new-session -s "${1:-$(date +w-%m%d-%Hh%M)}"; }
ta() {
  if [[ -n "$1" ]]; then
    tmux attach-session -t "$1"
  else
    tmux attach-session
  fi
}

# tab-completion for ta: complete with tmux session names
_ta() {
  local sessions=(${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"})
  _describe 'tmux session' sessions
}
compdef _ta ta

# WezTerm without tmux (overrides default_prog)
alias wez='wezterm start -- /bin/zsh &'

# ---------------------------------------------------------------------------- #
#                                     PATH                                     #
# ---------------------------------------------------------------------------- #

path_prepend "/usr/local/cuda-12.2/bin"

# ---------------------------------------------------------------------------- #
#                                   GPU Cuda                                   #
# ---------------------------------------------------------------------------- #

# Append CUDA library paths if available
for cuda_lib in /usr/lib/cuda/lib64 /usr/lib/cuda/include /usr/local/cuda-12.2/lib64; do
  [[ -d $cuda_lib ]] && export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$cuda_lib"
done

# ---------------------------------------------------------------------------- #
#                                     START                                    #
# ---------------------------------------------------------------------------- #

# Machine-specific PATH tweaks
case $WHICH_COMPUTER in
  TheBeast)
    path_append "$HOME/.AppImage"
    path_append "/home/ezalos/.local/bin" ;;
  MacBook|MacBook_Heuritech)
    path_prepend "/opt/homebrew/opt/libpq/bin"
    path_prepend "/opt/homebrew/opt/coreutils/libexec/gnubin"
    path_append  "/Applications/Docker.app/Contents/Resources/bin" ;;
esac

if [[ $WHICH_COMPUTER == "MacBook" ]] || [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
    path_prepend "/opt/homebrew/opt/grep/libexec/gnubin"
fi


if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
    . "$HOME/.cargo/env"
    export PYTHON_INSTALLED="/usr/bin/python3"
    export SYSTEM_PYTHON="/usr/bin/python3"
    export PATH="$PATH:/usr/lib/dart/bin"
fi

if [[ $WHICH_COMPUTER == "MacBook" ]] || [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
    # From: https://superuser.com/questions/399594/color-scheme-not-applied-in-iterm2
    # Set CLICOLOR if you want Ansi Colors in iTerm2 
    export CLICOLOR=1
    # Set colors to match iTerm2 Terminal Colors
    export TERM=xterm-256color
    . "$HOME/.local/bin/env"

    # The following lines have been added by Docker Desktop to enable Docker CLI completions.
    fpath=(/Users/ezalos/.docker/completions $fpath)
    autoload -Uz compinit
    compinit
    # End of Docker CLI completions
fi


if [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
    # rosetta terminal setup
    if [ $(arch) = "i386" ]; then
        alias brew86="/usr/local/bin/brew"
        alias pyenv86="arch -x86_64 pyenv"
    fi
fi

# This is zsh-specific syntax for rebuilding the PATH environment variable from an array.
export PATH=${(j.:.)path}
# zprof

# Lazy-load NVM to avoid ~1.5 s startup penalty on every shell
export NVM_DIR="$HOME/.nvm"
lazy_load_nvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { lazy_load_nvm && nvm  "$@"; }
node() { lazy_load_nvm && node "$@"; }
npm()  { lazy_load_nvm && npm  "$@"; }
npx()  { lazy_load_nvm && npx  "$@"; }

# TheBeast: add nvm node binaries to PATH so non-interactive tools (make, /bin/sh)
# can find globally installed packages like marp without triggering lazy-load
if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
    local _nvm_node_dirs=("$NVM_DIR"/versions/node/*(On))
    if (( ${#_nvm_node_dirs} )); then
        path_append "${_nvm_node_dirs[1]}/bin"
    fi
fi
