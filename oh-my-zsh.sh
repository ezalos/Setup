#!/bin/bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	# Linux
	sed -i "s~ZSH_THEME=\"robyrussell\"~ZSH_THEME=\"agnoster\"~g" ~/.zshrc
elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	sed -i '' 's~ZSH_THEME="robyrussell"~ZSH_THEME="agnoster"~g' ~/.zshrc
	source ~/.zshrc
	curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim-macos.tar.gz
	tar xzf nvim-macos.tar.gz
	alias nvim='~/Setup/nvim-osx64/bin/nvim'
	mkdir -p ~/.config
	git clone https://github.com/ezalos/nvim.git ~/.config/nvim
	curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	nvim --headless +PlugInstall +qa
#elif [[ "$OSTYPE" == "cygwin" ]]; then
	# POSIX compatibility layer and Linux environment emulation for Windows
#elif [[ "$OSTYPE" == "msys" ]]; then
	# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
#elif [[ "$OSTYPE" == "win32" ]]; then
	# I'm not sure this can happen.
#elif [[ "$OSTYPE" == "freebsd"* ]]; then
	# ...
#else
	# Unknown.
fi
source ~/.zshrc
