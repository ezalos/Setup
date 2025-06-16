# ---------------------------------------------------------------------------- #
#                                     PATH                                     #
# ---------------------------------------------------------------------------- #

export PATH_SETUP_DIR="$HOME/Setup"

if [[ -d "$PATH_SETUP_DIR/bin" ]]; then
    export PATH=$PATH_SETUP_DIR/bin:$PATH
fi
if [[ -d "$PATH_SETUP_DIR/usr/bin" ]]; then
    export PATH=$PATH_SETUP_DIR/usr/bin:$PATH
fi
if [[ -d "$HOME/.local/bin" ]]; then
    export PATH=$HOME/.local/bin:$PATH
fi

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
ZSH_THEME="powerlevel10k/powerlevel10k"
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
elif [[ `uname -n` = "TheBeast" ]]; then
    export WHICH_COMPUTER="TheBeast"
elif [[ `uname -n` = "Louiss-MBP.lan" ]]; then
    export WHICH_COMPUTER="MacBook"
elif [[ `uname -n` = "Louiss-MacBook-Pro.local" ]]; then
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

# ---------------------------------------------------------------------------- #
#                                   SSH INIT                                   #
# ---------------------------------------------------------------------------- #

# Set up SSH agent and add key
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
fi

if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
SSH_KEY_PATH="$HOME/.ssh/id_ed_ghub"
elif [[ $WHICH_COMPUTER == "MacBook" ]]; then
SSH_KEY_PATH="$HOME/.ssh/gthb"
# elif [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
elif [[ $WHICH_COMPUTER =~ _Heuritech$ ]]; then
SSH_KEY_PATH="$HOME/.ssh/ghub_ezalos"
fi

# Add the key if it exists
if [ -n "$SSH_KEY_PATH" ] && [ -f "$SSH_KEY_PATH" ]; then
	ssh-add "$SSH_KEY_PATH" > /dev/null 2>&1
else
	echo "⚠️  Warning: SSH key $SSH_KEY_PATH not found"
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
function mkenv_pip() {
    cat > .envrc << EOF
#!$(which bash)

source ./venv/bin/activate

unset PS1
EOF
    # python3 -m pip install --upgrade pip
    if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
        python -m venv venv && direnv allow
    elif [[ $WHICH_COMPUTER == "MacBook" ]] || [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
        python3 -m venv venv && direnv allow
    fi
}

function mkenv_conda() {
    cat > .envrc << EOF
#!$(which bash)

eval "\$(conda shell.bash hook)"

conda activate ${PWD##*/}

unset PS1
EOF
    conda create -n ${PWD##*/} python=3.10 -y && direnv allow
}

function mkenv_uv() {
    cat > .envrc << EOF
#!$(which bash)

# source ./${PWD##*/}/bin/activate
source .venv/bin/activate

unset PS1
EOF
    # uv venv ${PWD##*/} && direnv allow
    uv venv && direnv allow
}
alias mkenv='mkenv_pip'

# General aliases
if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
alias copy='xclip -sel c'
elif [[ $WHICH_COMPUTER == "smic_Heuritech" ]]; then
alias copy='xclip -sel c'
elif [[ $WHICH_COMPUTER == "rnd_Heuritech" ]]; then
alias copy='xclip -sel c'
elif [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
alias copy='pbcopy'
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


# Machine-specific aliases
if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
    # ...
elif [[ $WHICH_COMPUTER == "MacBook" ]] || [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
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


# Setup repo management
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




# ---------------------------------------------------------------------------- #
#                                     PATH                                     #
# ---------------------------------------------------------------------------- #

export PATH=/usr/local/cuda-12.2/bin:$PATH

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

# Machine-specific aliases
if [[ $WHICH_COMPUTER == "TheBeast" ]]; then
    export PATH="$PATH:$HOME/.AppImage"
    # Created by `pipx` on 2024-07-15 15:54:12
    export PATH="$PATH:/home/ezalos/.local/bin"
elif [[ $WHICH_COMPUTER == "MacBook" ]] || [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
    export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
    export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin/"
fi

# echo "DEBUG: LINE 297"
# source ~/.autoenv/activate.sh
if [[ $WHICH_COMPUTER == "MacBook" ]] || [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then
    PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
    source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
elif [[ $WHICH_COMPUTER == "TheBeast" ]]; then
    source ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme
fi
# echo "DEBUG: LINE 305`"


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

eval "$(direnv hook zsh)"

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

# Heuritech specific
if [[ $WHICH_COMPUTER =~ _Heuritech$ ]]; then

    # Pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    # eval "$(pyenv init - zsh)"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"

    pythonpaths_monorepo_lib_src=$(find /home/ldevelle/monorepo/libraries -maxdepth 2 -name "src" -type d | tr '\n' ':' | sed 's/:$//')
    export PYTHONPATH="${PYTHONPATH}:${pythonpaths_monorepo_lib_src}"
fi

if [[ $WHICH_COMPUTER == "MacBook_Heuritech" ]]; then

    function rsync_monorepo {
        rsync -ravh \
            --exclude='.envrc' \
            --exclude='env' \
            --exclude='.python-version' \
            --exclude='.venv' \
            --exclude='venv' \
            --exclude='.git/*' \
            --exclude='*.pyc' \
            --exclude='__pycache__' \
            --exclude='.pytest_cache' \
            --exclude='.ipynb_checkpoint' \
            --exclude='untracked_files/data/*' \
            $HOME/monorepo/ \
            $1:monorepo/
    }
    # export -f rsync_monorepo

    # rosetta terminal setup
    if [ $(arch) = "i386" ]; then
        alias brew86="/usr/local/bin/brew"
        alias pyenv86="arch -x86_64 pyenv"
    fi


fi
