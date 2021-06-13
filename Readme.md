# My Setup

## Git clone self
```sh
cd ~
git clone https://github.com/ezalos/Setup.git
cd Setup
```
## Oh-My-ZSH
```sh
sh oh-my-zsh.sh
sh oh-my-zsh-themes.sh
```

## NVIM
```sh
sh nvim_setup.sh
```


# Contents
 - APT
```sh
sudo apt update && sudo apt upgrade
sudo apt install build-essential neovim git snapd python3 python3-pip zsh 
sudo apt install terminator neofetch
```

 - Oh-my-zsh
```sh
sudo apt install zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

 - nvim					#TODO
   - download
   - install
   - plugins

 - Dotfiles
```sh
cd ~/.oh-my-zsh/custom/plugins/
git clone https://github.com/zsh-users/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-history-substring-search
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/Tarrasch/zsh-autoenv ~/.dotfiles/lib/zsh-autoenv
#echo 'source ~/.dotfiles/lib/zsh-autoenv/autoenv.zsh' >> ~/.zshrc\n
```

 - pip install
   - Atleast everything needed for setup

 - My utils				#TODO
   - python indent
   - prototype catcher	#TODO

 - Programs
   - VScode config		#TODO

 - Background jobs		#TODO
   - emails