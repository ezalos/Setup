FROM ubuntu

# Removing debconf error messages from apt-get install
ARG DEBIAN_FRONTEND=noninteractive

# APT packages
RUN apt-get update && apt-get upgrade -y \
	&& apt-get install software-properties-common apt-utils vim git wget curl unzip neovim neofetch sudo -y \
	&& add-apt-repository ppa:deadsnakes/ppa \
	&& apt-get update \
	&& apt-get install python3 -y \
	&& yes | unminimize \
	&& apt-get install man-db -y \
	&& rm -rf /var/lib/apt/lists/*

# Oh-my-zsh setup
RUN echo 'Y' | sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.1/zsh-in-docker.sh)" -- \
	-t agnoster \
	-p https://github.com/zsh-users/zsh-syntax-highlighting \
	-p https://github.com/zsh-users/zsh-history-substring-search \
	-p https://github.com/zsh-users/zsh-autosuggestions 

# Download Setup
RUN git clone https://github.com/ezalos/Setup.git ~/Setup \
	&& cd ~/Setup \
	&& python3 scripts/dotfiles.py -a ~/.config/neofetch/config.conf \
	&& python3 scripts/dotfiles.py -a ~/.config/nvim/init.vim \
	&& python3 scripts/dotfiles.py -a ~/.zshrc \
	&& python3 scripts/dotfiles.py -a ~/.vimrc

# Neovim setup
RUN curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
	&& nvim --headless +PlugInstall +qa
# Error detected while processing /root/.config/nvim/init.vim:
# line  193:
# E185: Cannot find color scheme 'onehalfdark'Error detected while processing function <SNR>6_install[1]..<SNR>6_update_impl[113]..<SNR>6_update_vim[4]..<SNR>6_tick:
# line   17:
# E117: Unknown function: SyntasticStatuslineFlag
# E15: Invalid expression: SyntasticStatuslineFlag()

# Install personal tools
RUN mkdir -p ~/42 \
	&& cd ~/42 \
	&& git clone https://github.com/ezalos/Python_Indentation.git \
	&& git clone https://github.com/ezalos/libft.git
	# && git clone https://github.com/ezalos/emails.git \

ENTRYPOINT /bin/zsh
