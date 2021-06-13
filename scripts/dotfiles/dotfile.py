# File operations
import os
import shutil
from datetime import datetime
from config import config

def file_name(src):
	# TODO: Function uses a trick which is not viable long term
	if '/' in src:
		return src.split('/')[-1]
	return src

def get_time():
	now = datetime.now()
	current_time = now.strftime("%Y-%m-%d_%H:%M")
	return current_time

class DotFile():
	def __init__(self, path: str,
				alias: str=None, identifier:str=config.identifier,
				backups: list=[], main: str=None):
		"""[summary]
		DotFile allows to backup a dotfile or deploy it.
			It is an important element of my personal backup system

			Most parameters are just for allowing an easy load from database.

		Args:
			path (str): [Path to system .file]
			alias (str, optional): [.file name in the dotfiles directory]. Defaults to original filename.
			identifier (str, optional): [Naming the system, it's the 'computer + user']. Defaults to config.identifer.
			backups (str, optional): [path + id for the backups]. Defaults to None.
			main (str, optional): [Should be used as main .file]. Defaults to None.
		"""
		self.path = path
		# TODO: create alias suggestor one level up
		if alias == None:
			self.alias = file_name(self.path)
		else:
			self.alias = alias
		self.main = main
		self.backups = backups
		if identifier == None:
			identifier = config.identifier
		self.identifier = identifier

	def add_file(self, use_as_main=True, deploy=True):
		print(f'Adding {self.alias} from {self.path}')

		if os.path.islink(self.path):
			print(f'Error: {self.alias} is already a symlink')
			return
		self.backup()
		if use_as_main:
			self.copy_as_main()
		if deploy:
			self.deploy()

	def deploy(self):
		"""[summary]
			Deploy the dotfile in the system.
			/!\ Will delete the file -> should be used with add()
		"""
		dirs = os.path.dirname(self.path)
		print(f'Extarcting dir part of src: {dirs}')
		if os.path.exists(self.path):
			print(f'Deleting {self.path}')
			os.remove(self.path)
		# os.remove(self.path)
		if not os.path.exists(dirs):
			print(f'{dirs} does not exist: creating it')
			os.makedirs(dirs)
		main = config.project_path + self.main
		print(f"Symlink created {self.path} -> {main}")
		os.symlink(main, self.path)

	def backup(self):
		if os.path.exists(self.path):
			stime = get_time()
			backup_path = config.backup_dir \
							+ self.alias \
							+ '_' \
							+ config.identifier \
							+ '_' \
							+ stime
			shutil.copy(self.path, backup_path)
			print(f'Backed up as {backup_path}')
			# Unsure for identifier
			# It might be more pertinent to use the one in config
			meta = {
				'backup_path': backup_path,
				'identifier': self.identifier,
				'datetime': stime,
			}
			self.backups.append(meta)
		else:
			print(f'{self.path} does not exist, no backup will be done')

	def copy_as_main(self, force=False):
		self.main =  config.dotfiles_dir + self.alias
		if os.path.exists(self.main):
			print(f'File {self.path} already exist in Setup')
			if not force:
				return
		if os.path.exists(self.path):
			shutil.copy(self.path, self.main)
			print(f'{self.main} has been added as main for {self.path}')

	def to_db(self):
		self.dict = {
				'alias': self.alias,
				'path': self.path,
				'main': self.main,
				'identifier': self.identifier,
				'backups': self.backups,
		}
		return self.dict

	def from_db(self, data):
		alias = data['alias']
		main = data['main']
		path = data['path']
		backups = data['backups']
		identifier = data['identifier']
		self.__init__(path, alias=alias, identifier=identifier, backups=backups, main=main)

	def __str__(self):
		return str(self.to_db())