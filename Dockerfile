FROM ubuntu

# Removing debconf error messages from apt-get install
ARG DEBIAN_FRONTEND=noninteractive

# APT packages
RUN apt-get update && apt-get upgrade -y \
	&& apt-get install apt-utils vim git python3 wget curl unzip neovim -y \
	&& rm -rf /var/lib/apt/lists/*

# Oh-my-zsh setup
RUN echo 'Y' | sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.1/zsh-in-docker.sh)" -- \
	-t agnoster \
	-p https://github.com/zsh-users/zsh-syntax-highlighting \
	-p https://github.com/zsh-users/zsh-history-substring-search \
	-p https://github.com/zsh-users/zsh-autosuggestions 

# TMP: Python install
RUN apt install software-properties-common -y \
	&& add-apt-repository ppa:deadsnakes/ppa \
	&& apt update \
	&& apt install python3 -y \
	&& rm -rf /var/lib/apt/lists/*

# Download Setup
RUN git clone https://github.com/ezalos/Setup.git ~/Setup

# Dotfiles management
RUN cd ~/Setup \
	&& python3 scripts/dotfiles.py -a ~/.config/nvim/init.vim \
	&& python3 scripts/dotfiles.py -a ~/.zshrc \
	&& python3 scripts/dotfiles.py -a ~/.vimrc

# Neovim setup
RUN curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
	&& nvim --headless +PlugInstall +qa



# pip packages
# RUN /usr/local/bin/python -m pip install --upgrade pip \
# 	&& pip install Keras  Pillow  docopt  gym  imageio  imgaug \
# 	matplotlib  numpy  opencv_python  paho_mqtt  pandas  pickle-mixin \
# 	prettytable  progress  pyfiglet  pyzmq  requests  scikit_image \
# 	setuptools  simple_pid  tensorflow  torch  tornado  typing_extensions \
# 	GitPython  gym  matplotlib  numpy  pandas scikit-learn==0.23.2 sklearn \
# 	sklearn_deap  torch  tqdm

# Cloning projects
# RUN git clone https://github.com/ezalos/1st_DQN.git /dqn \
# 	&& cd /dqn && git checkout Louis 

ENTRYPOINT /bin/zsh