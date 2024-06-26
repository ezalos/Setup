import socket
import re
from getpass import getuser
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
	project_path = os.path.dirname(os.path.realpath(__file__))
	if pwd:
		surplus = "Setup/scripts/dotfiles"
	else:
		surplus = "scripts/dotfiles"
	if project_path[-len(surplus):] == surplus:
		project_path = project_path[:-len(surplus)]
	# project_path = "~/Setup/"
	print(f'Current {"pwd" if pwd else "project path"}: {project_path}')
	return project_path

config.pwd = get_project_path(pwd=False)
config.project_path = get_project_path()
config.dotfiles_dir = 'dotfiles/'
config.backup_dir = config.dotfiles_dir + 'old/'
config.depedencies_path = config.dotfiles_dir + 'meta.json'
config.identifier = get_computer_name()

print(f"{config.identifier = }")
