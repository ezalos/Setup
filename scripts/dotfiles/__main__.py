import argparse
from database import Depedencies
from config import config
from dotfile import DotFile


class Backup():
	def __init__(self):
		self.db = Depedencies()
		self.depedencies = self.db.load()
		self.data = self.load_all(self.db)
	
	def load_all(self, db):
		depedencies = db.load()
		data = []
		for dep in depedencies.values():
			for d in dep:
				dot = DotFile(d['path'])
				dot.from_db(d)
				print(dot)
				data.append(dot)
		return data

	def transform_db(self):
		# Should be stored by Alias
		# Backup should be a list:
		#	Computer
		#	Date
		#	Original path
		alias_dic = {}
		for dot in self.data:
			if dot.alias not in alias_dic:
				alias_dic[dot.alias] = [dot]
			else:
				alias_dic[dot.alias].append(dot)

		new_db = []
		for alias in alias_dic.values():
			backups = []
			for dot in alias:
				backups.append(dot.backups)
			alias[0].backups = backups
			new_db.append(alias[0].to_db())
			
		self.data = new_db

	def save_all(self):
		self.db.save(self.data)

	def add_elem(self, path, alias=None):
		dot = DotFile(path, alias)
		# dot.ad

		pass

	def deploy_elem(self):
		pass

	def deploy(self):
		pass

parser = argparse.ArgumentParser()
parser.add_argument('-a', '--add', nargs='+', help='-a SRC [.filename]	Add one file to setup, create backup, make symlink')
parser.add_argument('-f', '--force', default=False, action='store_true', help='Force file remplacement')
parser.add_argument('-k', '--keep', default=False, action='store_true', help='Will not alter source file')
args = parser.parse_args()

# if args.add:
# 	src = args.add[0]
# 	dst = args.add[1] if len(args.add) >= 2 else None
# 	add_file(src, dst, args.force, args.keep)

b = Backup()
b.transform_db()
b.save_all()