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
		for d in depedencies:
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
		pass
		

	def save_all(self):
		to_db = []
		for d in self.data:
			to_db.append(d.to_db())
		self.db.save(to_db, test=True)

	def add_elem(self, path, alias=None):
		dot = DotFile(path, alias)
		# dot.ad

		pass

	def deploy_elem(self):
		pass

	def deploy(self):
		for d in self.data:
			d.deploy()

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
b.deploy()
b.save_all()