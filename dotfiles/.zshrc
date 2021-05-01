# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    .zshrc                                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: ezalos <ezalos@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2021/03/27 23:02:39 by ezalos            #+#    #+#              #
#    Updated: 2021/04/29 13:59:40 by ezalos           ###   ########.fr        #
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

[[ -s /home/ezalos/.autojump/etc/profile.d/autojump.sh ]] && source /home/ezalos/.autojump/etc/profile.d/autojump.sh

autoload -U compinit && compinit -u
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

bindkey '^[[1;5A' history-substring-search-up
bindkey '^[[1;5B' history-substring-search-down


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


#------------
#  Starting
#------------

neofetch --disable Public_IP --separator '\t'


source ~/.autoenv/activate.sh
