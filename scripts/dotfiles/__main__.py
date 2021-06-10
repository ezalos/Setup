import argparse
from database import Depedencies
from config import config
from dotfile import DotFile

parser = argparse.ArgumentParser()
parser.add_argument('-a', '--add', nargs='+', help='-a SRC [.filename]	Add one file to setup, create backup, make symlink')
parser.add_argument('-f', '--force', default=False, action='store_true', help='Force file remplacement')
parser.add_argument('-k', '--keep', default=False, action='store_true', help='Will not alter source file')
args = parser.parse_args()

if args.add:
	src = args.add[0]
	dst = args.add[1] if len(args.add) >= 2 else None
	add_file(src, dst, args.force, args.keep)
