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
	def __init__(self, path: str, alias: str=None, backup: str=None, main: str=None):
		"""[summary]
		DotFile allows to backup a dotfile or deploy it.
			It is an important element of my personal backup system

			Most parameters are just for allowing an easy load from database.

		Args:
			path (str): [Path to system .file]
			alias (str, optional): [.file name in the dotfiles directory]. Defaults to original filename.
			backup (str, optional): [path for the backup]. Defaults to None.
			main (str, optional): [Should be used as main .file]. Defaults to None.
		"""
		self.path = path
		print(self.path)
		self.name = file_name(self.path)
		if alias == None:
			self.alias = self.name
		else:
			self.alias = alias
		if backup:
			self.backup_path = backup
		else:
			# Time do not reflect the moment file is saved.
			# 	If better idea: will be changed
			self.backup_path = config.backup_dir \
							+ self.name \
							+ '_' \
							+ config.identifier \
							+ '_' \
							+ get_time()
		self.main = main

	def add_file(self,
				src, 
				dst=None,
				force_dst_update=False,
				keep_src=False):
		print(f'Adding {dst} from {src}')
		if os.path.islink(src):
			print(f'Error: {src} is already a symlink')
			return
		self.backup()
		if force_dst_update:
			self.copy_as_main()
		if not keep_src:
			self.deploy()

	def deploy(self):
		"""[summary]
			Deploy the dotfile in the system.
			/!\ Will delete the file -> should be used with add()
		"""
		if os.path.exists(src):
			os.remove(src)
		dirs = os.path.dirname(src)
		print(f'Extarcting dir part of src: {dirs}')
		if not os.path.exists(dirs):
			print(f'{dirs} does not exist: creating it')
			os.makedirs(dirs)
		saved_main = config.project_path + config.dotfiles_dir + self.main
		os.symlink(PWD + DOTFILE_DIR + dst, src)

	def backup(self):
		if os.path.exists(self.path):
			shutil.copy(self.path, self.dotfiles_dir + self.name)
			print(f'Backed up as {self.dotfiles_dir + self.name}')
		else:
			print(f'{src} does not exist, no backup will be done')

	def copy_as_main(self):
		self.main =  config.dotfiles_dir + self.name
		if not os.path.exists(self.main):
			if os.path.exists(self.path):
				shutil.copy(self.path, self.main)
				self.is_main = True
				print(f'{self.main} has been added as main for {self.path}')
		else:
			print(f'File {self.path} already exist in Setup')

	def to_db(self):
		self.dict = {
				'alias': self.alias,
				'path': self.path,
				'main': self.main,
				'backup': self.backup_path,
				'identifier': config.identifier,
		}
		return self.dict

	def from_db(self, data):
		alias = data[0]
		path = data[1]
		# identifier = data[2]
		self.__init__(path, alias=alias)

	def __str__(self):
		return str(self.to_db())