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

#-------------
#  Oh-my-zsh
#-------------

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="agnoster"
source $ZSH/oh-my-zsh.sh

#Dont put in cmd history command starting with whitespace
HISTCONTROL=ignorespace

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

#--------
#  Init
#--------

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
else
   export EDITOR='nvim'
fi


#-----------
#  Plugins
#-----------


source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.oh-my-zsh/custom/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

plugins=(git)

#---------
#  Conda
#---------

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


#-----------
#  BINDKEY
#-----------

bindkey '^[[1;2A' history-substring-search-up
bindkey '^[[1;2B' history-substring-search-down


#---------
#  ALIAS
#---------

alias indent="python3 ~/42/Python_Indentation/Indent.py -f"
alias gcl="git clone"
alias pyg="pygmentize"
# open ~/.zshrc in using the default editor specified in $EDITOR
alias ec="$EDITOR $HOME/.zshrc"
# source ~/.zshrc
alias sc="source $HOME/.zshrc"
#alias t="todo-txt"
#alias tl="todo-txt ls"
#alias tr="todo-txt replace"
#alias ta="todo-txt add"
alias neo="neofetch --separator '\t'"

alias iscuda="python -c 'import sys; print(f\"{sys.version = }\"); import torch; print(f\"{torch. __version__ = }\"); print(f\"{torch.cuda.is_available() = }\"); print(f\"{torch.cuda.device_count() = }\")'"

if [[ `uname -n` = "ezalos-TM1704" ]]
then
alias bt="batcat --paging=never --style=plain "
else
alias bt="bat --paging=never --style=plain "
fi

if [[ `uname -n` = "ezalos-TM1704" ]]
then
	alias mkenv_conda='echo "#!$(which bash)\n\neval \"\$(conda shell.bash hook)\"\n\nconda activate ${PWD##*/}\n\nunset PS1\n" > .envrc && conda create -n ${PWD##*/} python=3.10 -y && direnv allow'
else
	alias mkenv_conda='echo "#!$(which bash)\n\neval \"\$(conda shell.bash hook)\"\n\nconda activate ${PWD##*/}\n\nunset PS1\n" > .envrc && conda create -n ${PWD##*/} python=3.10 -y && direnv allow'
fi
alias mkenv_pip='python -m venv venv && echo "#!$(which bash)\n\n source ./venv/bin/activate\n" > .envrc && direnv allow'
alias mkenv='mkenv_conda'

alias docker_clean_images='docker rmi $(docker images -a --filter=dangling=true -q)'
alias docker_clean_ps='docker rm $(docker ps --filter=status=exited --filter=status=created -q)'
alias docker_kill_all='docker kill $(docker ps -a -q)'

ICONO_DIRECTORY="/home/ezalos/42/icono-web"
alias ic_dl="bash $ICONO_DIRECTORY/scripts/monitor/download.sh"
alias ic_dl_gib="bash $ICONO_DIRECTORY/scripts/monitor/download_gib_time.sh"
alias ic_dl_speed="bash $ICONO_DIRECTORY/scripts/monitor/download_speed.sh"
alias ic_ex="bash $ICONO_DIRECTORY/scripts/monitor/extract.sh"
alias ic_exs="bash $ICONO_DIRECTORY/scripts/monitor/extract_details.sh"
alias ic_em="bash $ICONO_DIRECTORY/scripts/monitor/embed.sh"
alias ic="bash $ICONO_DIRECTORY/scripts/monitor/all.sh"
#------------
#  GPU Cuda
#------------

export LD_LIBRARY_PATH=/usr/lib/cuda/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/cuda/include:$LD_LIBRARY_PATH

#------------
#  Starting
#------------

# source ~/.autoenv/activate.sh
source ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# neofetch --disable Public_IP --separator '\t'

# source ~/.dotfiles/lib/zsh-autoenv/autoenv.zsh

# export PATH=/home/ezalos/miniconda3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/home/ezalos/miniconda3/bin:/home/ezalos/.local/bin


# add Pulumi to the PATH
export PATH="$PATH:$HOME/.pulumi/bin"

eval "$(direnv hook zsh)"
