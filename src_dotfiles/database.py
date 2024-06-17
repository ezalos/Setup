from dotfiles.config import config
import json
from dotfiles.dotfile import DotFile
from pathlib import Path
class Depedencies():
    def __init__(self):
        self.depedencies = None
        self.path = config.depedencies_path
        self.path_test = config.dotfiles_dir + 'test_' + 'meta.json'

    def load(self, test=False):
        """[summary]
            Loads the db in memory
        Args:
            test (bool, optional): [Use test db]. Defaults to False.

        Returns:
            [type]: [description]
        """
        dest = self.path_test if test  else self.path
        
        db_path = Path(config.project_path).joinpath(dest)
        print(f"{db_path = }")

        with open(db_path) as json_file:
            self.depedencies = json.load(json_file)
        return self.depedencies

    def load_all(self, test=False):
        """[summary]
            Converts the raw_db data in usable objects

        Args:
            test (bool, optional): [Use test db]. Defaults to False.

        Returns:
            [type]: [description]
        """
        depedencies = self.load(test)
        data = []
        for d in depedencies:
            dot = DotFile(d['path'])
            dot.from_db(d)
            print(f"Loaded {dot.path}")
            data.append(dot)
        return data

    def save(self, depedencies, test=False):
        """[summary]
            Saves raw_db on disk

        Args:
            depedencies ([type]): [description]
            test (bool, optional): [Use test db]. Defaults to False.
        """
        dest = self.path_test if test  else self.path
        with open(dest, 'w') as backup:
            json.dump(depedencies, backup, indent=4)

    def save_all(self, data, test=False):
        """[summary]
        Converts dotfile objects to raw_db data

        Args:
            test (bool, optional): [Use test db]. Defaults to False.
        """
        to_db = []
        for d in data:
            to_db.append(d.to_db())
        self.save(to_db, test=test)

        # def __contains__(self, key):
    # 	# * Here to surcharge 'in' operator
    #     return key in self.numbers
