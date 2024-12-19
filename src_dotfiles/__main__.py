#!/usr/bin/env python3

import argparse
from src_dotfiles.database import Depedencies
from src_dotfiles.config import config
from src_dotfiles.dotfile import DotFile

def path_security_check(path):
	if not path.startswith(config.home):
		print(f"/!\\ CAREFULL -> Path {path} do not start by {config.home}")
		print("\tCurrent path resolution might cause a lot of problems")
		if 'y' != input("If you are sure to continue: enter 'y':"):
			print("Exiting...")
			return True
	return False

class Backup():
	def __init__(self, args):
		self.db = Depedencies()
		if args.update_test:
			print(f"Updating {self.db.path_test} from {self.db.path}")
			self.data = self.db.load_all(test=True)
			self.save()
		if args.test:
			print(f"Using test database: {self.db.path_test}")
		self.data = self.db.load_all(args.test)
		if args.add_deploy == "add":
			if args.path and path_security_check(args.path):
				return
			print("Add!")
			self.add(args)
		elif args.add_deploy == "deploy":
			print("Deploy!")
			self.deploy(args)
		self.save(test=args.test)

	def add_exists(self, exists, dot):
		# Dotfile is already in the system with possibly a different path
		# Complexity here comes from db architecture
		# 	db suppose there is only one path for all devices
		#	Which obviously could sometime be False
		# Everything could be more simple by having a structure
		# 	Similar to backup for the main
		#	One main path (... I mean if I need 2 shouldn't I use another alias ?)
		#	list of Devices/System_path -> with autocompletion
		print(f"Alias {exists.alias} already exists in the system")
		if exists.path == dot.path:
			print("Argument path is the same as the one in the system")
			# Path resolution is way more complex than this :/
			exists.backup()
			exists.deploy()
		else:
			print("Argument path is different from the one in the system")
			print(f"{exists.path} != {dot.path}")
			raise NotImplemented

	def add(self, args):
		if args.alias == "":
			# User wants help selecting alias
			dot = DotFile(args.path)
			exists = self.select_alias(alias=None)
			self.add_exists(exists, dot)
		else:
			dot = DotFile(args.path, alias=args.alias)
			if args.alias == None:
				# User did not use alias
				print(f"Alias generated from path: {dot.alias}")
			exists = self.select_alias(alias=dot.alias)
			if exists:
				self.add_exists(exists, dot)
			else:
				print(f"Alias {dot.alias} is new for the system")
				dot.add_file()
				self.data.append(dot)

	def deploy(self, args):
		if args.alias:
			print(f"User wants to deploy {args.alias}")
			dot = self.select_alias(alias=args.alias)
			if dot == None:
				print(f"Impossible to find alias, asking user")
				dot = self.select_alias(alias=None)
			self.deploy_elem(dot)
		else:
			self.deploy_all()

	def deploy_elem(self, dot):
		print(f"Deploying {dot.alias}")
		dot.backup()
		dot.deploy()

	def deploy_all(self):
		for d in self.data:
			self.deploy_elem(d)

	def select_alias(self, alias=None):
		if alias == None:
			from simple_term_menu import TerminalMenu
			selection = [d.alias for d in self.data]
			terminal_menu = TerminalMenu(selection)
			menu_entry_index = terminal_menu.show()
			return self.data[menu_entry_index]
		else:
			selection = [d for d in self.data if d.alias == alias]
			if len(selection) == 1:
				return selection[0]
			elif len(selection) > 1:
				print(f"There is {len(selection)} dotfiles named {alias}")
				for d in selection:
					print(d)
				print("Selecting 1st entry!")
				return selection[0]
			else:
				print(f"There is no match in database for {alias}")
				return None

	def save(self, test=False):
		self.db.save_all(self.data, test=test)


# create the top-level parser
parser = argparse.ArgumentParser()
parser.add_argument('-u', '--update_test', action='store_true', help='Update test db')
parser.add_argument('-t', '--test', action='store_true', help='Use test db')

# Creation of subparsers Add and Deploy
subparsers = parser.add_subparsers(help='Add or Deploy a dotfile', dest="add_deploy")
# create the parser for the "add" command
parser_add = subparsers.add_parser('add', help='Add a file to the backup')
parser_add.add_argument('path', type=str, help='dotfile path')
parser_add.add_argument('-a', '--alias', nargs="?", type=str, const="", help='Alias to use for dotfile')

# create the parser for the "deploy" command
parser_deploy = subparsers.add_parser('deploy', help='Deploy a file from the backup')
parser_deploy.add_argument('-a', '--alias', type=str, help='if None -> deploy all ; if nonsense -> asks user')

# Parsing args
args = parser.parse_args()


b = Backup(args)
