#!/bin/bash
curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim-macos.tar.gz
tar xzf nvim-macos.tar.gz
alias nvim='~/Setup/nvim-osx64/bin/nvim'
mkdir -p ~/.config
git clone https://github.com/ezalos/nvim.git ~/.config/nvim
curl -fLo "~/.local/share/nvim/site/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
~/Setup/nvim-osx64/bin/nvim --headless +PlugInstall +qa
