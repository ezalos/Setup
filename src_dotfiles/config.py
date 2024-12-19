import socket
import re
from getpass import getuser
from pathlib import Path
import os

class DotDict(dict):
    """
    a dictionary that supports dot notation 
    as well as dictionary access notation 
    usage: d = DotDict() or d = DotDict({'val1':'first'})
    set attributes: d.val2 = 'second' or d['val2'] = 'second'
    get attributes: d.val2 or d['val2']
    """
    __getattr__ = dict.__getitem__
    __setattr__ = dict.__setitem__
    __delattr__ = dict.__delitem__

config = DotDict()

def get_computer_name():
	identifier = socket.gethostname() + "." + getuser()
	identifier = re.sub(r"[^A-Za-z0-9\.]", ".", identifier)
	if identifier[-1] == ".":
		identifier = identifier + 'x'
	return identifier

def get_project_path(pwd=False):
    # TODO: Function uses a trick which is not viable long term
    project_path = Path(__file__).parent.parent.as_posix() # ~/Setup
    if pwd:
        surplus = "Setup/src_dotfiles"
    else:
        surplus = "src_dotfiles"
    if project_path[-len(surplus):] == surplus:
        project_path = project_path[:-len(surplus)]
    # project_path = "~/Setup/"
    print(f'Current {"pwd" if pwd else "project path"}: {project_path}')
    return project_path


def get_home_path():
    # TODO: Function uses a trick which is not viable long term
    home_path = Path(__file__).parent.parent.parent.as_posix()  # /home/ezalos (if cloned directly)
    print(f'Current home path: {home_path}')
    return home_path


config.pwd = get_project_path(pwd=False)
config.home = get_home_path()
config.project_path = get_project_path()
config.dotfiles_dir = 'dotfiles'
config.backup_dir = Path(config.dotfiles_dir).joinpath('old').as_posix()
config.depedencies_path = Path(config.dotfiles_dir).joinpath('meta.json').as_posix()
config.identifier = get_computer_name()

print(f"{config.identifier = }")
