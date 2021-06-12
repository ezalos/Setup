import argparse
from database import Depedencies
from config import config
from dotfile import DotFile


class Backup():
	def __init__(self):
		self.db = Depedencies()
		self.depedencies = self.db.load()
		self.data = []
		for dep in self.depedencies:
			dot = DotFile(dep[1])
			dot.from_db(dep)
			print(dot)
			self.data.append(dot.to_db())
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