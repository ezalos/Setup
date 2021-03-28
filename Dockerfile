FROM ubuntu

# Removing debconf error messages from apt-get install
ARG DEBIAN_FRONTEND=noninteractive

# APT packages
RUN apt-get update && apt-get upgrade -y \
	&& apt-get install apt-utils vim git python3 wget curl unzip -y \
	&& rm -rf /var/lib/apt/lists/*

# Oh-my-zsh setup
RUN echo 'Y' | sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.1/zsh-in-docker.sh)" -- \
	-t agnoster \
	-p https://github.com/zsh-users/zsh-syntax-highlighting \
	-p https://github.com/zsh-users/zsh-history-substring-search \
	-p https://github.com/zsh-users/zsh-autosuggestions 



ENTRYPOINT /bin/zsh

# pip pacages
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