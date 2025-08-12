# ---------------------------------------------------------------------------- #
#                                     PATH                                     #
# ---------------------------------------------------------------------------- #

export PATH_SETUP_DIR="$HOME/Setup"
# Helper utilities ---------------------------------------------------- #
# Functions to safely add directories to $PATH (duplicates removed)
path_prepend() { for d in "$@"; do [[ -d $d ]] && path=($d $path); done }
path_append()  { for d in "$@"; do [[ -d $d ]] && path+=($d);     done }
typeset -gU path

# Sensible zsh options ------------------------------------------------ #
setopt autocd pushd_ignore_dups share_history hist_ignore_space inc_append_history 
# zmodload zsh/zprof

# Initial PATH bootstrap
path_prepend "$PATH_SETUP_DIR/bin" "$PATH_SETUP_DIR/usr/bin" "$HOME/.local/bin"

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
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

ZSH_THEME="powerlevel10k/powerlevel10k"
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
    path_append "$HOME/.AppImage" "/home/ezalos/.local/bin" ;;
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

export PATH=${(j.:.)path}
# zprof