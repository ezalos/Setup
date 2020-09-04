#!/bin/bash
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	# Linux
	sed -i 's~ZSH_THEME=\"robbyrussell~ZSH_THEME=\"agnoster~g' ~/.zshrc
elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	sed -i '' 's~ZSH_THEME=\"robbyrussell~ZSH_THEME=\"agnoster~g' ~/.zshrc
fi
source ~/.zshrc
