# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    .zshrc                                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: ezalos <ezalos@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2021/03/27 23:02:39 by ezalos            #+#    #+#              #
#    Updated: 2021/05/13 09:38:20 by ezalos           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# ---------------------------------------------------------------------------- #
#                                   Oh-my-zsh                                  #
# ---------------------------------------------------------------------------- #
# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="agnoster"
source $ZSH/oh-my-zsh.sh
HISTCONTROL=ignorespace
export LANG=en_US.UTF-8

# ---------------------------------------------------------------------------- #
#                                     Init                                     #
# ---------------------------------------------------------------------------- #

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
else
   export EDITOR='nvim'
fi

# Set computer identifier
if [[ `uname -n` = "ezalos-TM1704" ]]; then
    export WHICH_COMPUTER="TheBeast"
elif [[ `uname -n` = "Louiss-MBP.lan" ]]; then
    export WHICH_COMPUTER="MacBook"
elif [[ `uname -n` = "Louiss-MacBook-Pro.local" ]]; then
    export WHICH_COMPUTER="MacBook"
else
    export WHICH_COMPUTER="Unknown"
fi


# ---------------------------------------------------------------------------- #
#                                    Plugins                                   #
# ---------------------------------------------------------------------------- #


source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.oh-my-zsh/custom/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

plugins=(git)

#  BINDKEY

bindkey '^[[1;2A' history-substring-search-up
bindkey '^[[1;2B' history-substring-search-down


# ---------------------------------------------------------------------------- #
#                                     Conda                                    #
# ---------------------------------------------------------------------------- #

export PATH=$PATH:/home/ezalos/miniconda3/bin
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/ezalos/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/ezalos/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/ezalos/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/ezalos/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<



# ---------------------------------------------------------------------------- #
#                                     ALIAS                                    #
# ---------------------------------------------------------------------------- #

# Environment management aliases
mkenv_pip() {
    cat > .envrc << EOF
#!$(which bash)

source ./venv/bin/activate

unset PS1
EOF
    # python3 -m pip install --upgrade pip

    # Machine-specific aliases
    if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
        python -m venv venv && direnv allow
    elif [[ $WHICH_COMPUTER == "MacBook" ]]; then
        python3 -m venv venv && direnv allow
    fi
}

mkenv_conda() {
    cat > .envrc << EOF
#!$(which bash)

eval "\$(conda shell.bash hook)"

conda activate ${PWD##*/}

unset PS1
EOF
    conda create -n ${PWD##*/} python=3.10 -y && direnv allow
}
alias mkenv='mkenv_pip'


# General aliases
alias copy='xclip -sel c'
alias indent="python3 ~/42/Python_Indentation/Indent.py -f"
alias gcl="git clone"
alias ec="$EDITOR $HOME/.zshrc"
alias sc="source $HOME/.zshrc"
alias neo="neofetch --separator '\t'"
alias iscuda="python3 -c 'import sys; print(f\"{sys.version = }\"); import torch; print(f\"{torch. __version__ = }\"); print(f\"{torch.cuda.is_available() = }\"); print(f\"{torch.cuda.device_count() = }\")'"
alias bt="batcat --paging=never --style=plain "


# Machine-specific aliases
if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
    # ...
elif [[ $WHICH_COMPUTER == "MacBook" ]]; then
    # ...
fi

# Docker cleanup aliases
alias docker_clean_images='docker rmi $(docker images -a --filter=dangling=true -q)'
alias docker_clean_ps='docker rm $(docker ps --filter=status=exited --filter=status=created -q)'
alias docker_kill_all='docker kill $(docker ps -a -q)'
alias docker_clean_overlay='docker rm -vf $(docker ps --filter=status=exited --filter=status=created -q) ; docker rmi -f $(docker images --filter=dangling=true -q) ; docker volume prune -f ; docker system prune -a -f'

# Icono project aliases
ICONO_DIRECTORY="/home/ezalos/42/icono-web"
alias ic_dl="bash $ICONO_DIRECTORY/scripts/monitor/remote/download.sh"
alias ic_dt="bash $ICONO_DIRECTORY/scripts/monitor/remote/detailer.sh"
alias ic_ex="bash $ICONO_DIRECTORY/scripts/monitor/remote/extract.sh"
alias ic_em="bash $ICONO_DIRECTORY/scripts/monitor/embed.sh"
alias ic="bash $ICONO_DIRECTORY/scripts/monitor/all.sh"


# ---------------------------------------------------------------------------- #
#                                   GPU Cuda                                   #
# ---------------------------------------------------------------------------- #
export LD_LIBRARY_PATH=/usr/lib/cuda/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/cuda/include:$LD_LIBRARY_PATH
export PATH=/usr/local/cuda-12.2/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.2/lib64:$LD_LIBRARY_PATH

# ---------------------------------------------------------------------------- #
#                                     START                                    #
# ---------------------------------------------------------------------------- #

# source ~/.autoenv/activate.sh
if [[ `uname -n` = "Louiss-MBP.lan" ]]
then
PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
else
source ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# Machine-specific aliases
if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
    export PATH="$PATH:$HOME/.AppImage/"
elif [[ $WHICH_COMPUTER == "MacBook" ]]; then
    export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi

eval "$(direnv hook zsh)"


# ---------------------------------------------------------------------------- #
#                                    NOT ME                                    #
# ---------------------------------------------------------------------------- #

# Created by `pipx` on 2024-07-15 15:54:12
export PATH="$PATH:/home/ezalos/.local/bin"

# From: https://superuser.com/questions/399594/color-scheme-not-applied-in-iterm2
# Set CLICOLOR if you want Ansi Colors in iTerm2 
export CLICOLOR=1
# Set colors to match iTerm2 Terminal Colors
export TERM=xterm-256color

. "$HOME/.cargo/env"
