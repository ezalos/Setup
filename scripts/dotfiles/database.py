from config import config
import json

class Depedencies():
	def __init__(self):
		self.depedencies = None

	def load(self):
		with open(config.depedencies_path) as json_file:
			self.depedencies = json.load(json_file)
		return self.depedencies

    # def __contains__(self, key):
	# 	# * Here to surcharge 'in' operator
    #     return key in self.numbers

	def save(self, depedencies):
		# TODO: Remove _test
		# dest = config.dotfiles_dir + "test_" + 'depedencies.json'
		dest = config.depedencies_path 
		with open(dest, 'w') as backup:
			json.dump(depedencies, backup, indent=4)

		