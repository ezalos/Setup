from src_dotfiles.config import config
import json
from src_dotfiles.DotFile import DotFile
from pathlib import Path
from ezpy_logs.LoggerFactory import LoggerFactory

logger = LoggerFactory.getLogger(__name__)

# Moving parts by identifiers:
# - hostname
# - HOME directory :
#       Allow to reuse between OS :
#           -> Mac /Users/ezalos  to /home/ezalos in linux
#       Allow to reuse between users and root :
#           -> /home/ezalos in linux to /home/root in docker
# - Setup location :
#       At the moment everything is in HOME/Setup/dotfiles, but should be configurable


class Depedencies():
    def __init__(self):
        self.test = False
        self.depedencies = None
        logger.debug(f"{config.depedencies_path = }")
        logger.debug(f"{config.dotfiles_dir = }")
        self.path = config.depedencies_path
        self.path_test = config.dotfiles_dir + "test_" + "meta.json"
        self.data = self.load_all()

    def load(self):
        """[summary]
            Loads the db in memory
        Args:
            test (bool, optional): [Use test db]. Defaults to False.

        Returns:
            [type]: [description]
        """
        dest = self.path_test if self.test  else self.path

        db_path = Path(config.project_path).joinpath(dest)
        logger.debug(f"{db_path = }")

        if not db_path.exists():
            self.depedencies = []
            return self.depedencies

        with open(db_path) as json_file:
            self.depedencies = json.load(json_file)
        return self.depedencies

    def load_all(self):
        """[summary]
            Converts the raw_db data in usable objects

        Args:
            test (bool, optional): [Use test db]. Defaults to False.

        Returns:
            [type]: [description]
        """
        depedencies = self.load()
        data = []
        for d in depedencies:
            dot = DotFile(d['path'])
            dot.from_db(d)
            logger.debug(f"Loaded {dot.path}")
            data.append(dot)
        return data

    def save(self, depedencies):
        """[summary]
            Saves raw_db on disk

        Args:
            depedencies ([type]): [description]
            test (bool, optional): [Use test db]. Defaults to False.
        """
        dest = self.path_test if self.test  else self.path
        logger.info(f"Saving to {dest}")
        with open(dest, 'w') as backup:
            json.dump(depedencies, backup, indent=4)

    def save_all(self):
        """[summary]
        Converts dotfile objects to raw_db data

        Args:
            test (bool, optional): [Use test db]. Defaults to False.
        """
        to_db = []
        for d in self.data:
            logger.debug(f"Adding {d.alias = } {d.path = } to future backup")
            to_db.append(d.to_db())
        self.save(to_db)

    def select_by_alias(self, alias):
        selection = [d for d in self.data if d.alias == alias]
        if len(selection) == 1:
            return selection[0]
        elif len(selection) > 1:
            logger.warning(f"There is {len(selection)} dotfiles named {alias}")
            for d in selection:
                logger.warning(str(d))
            logger.warning("Selecting 1st entry!")
            return selection[0]
        else:
            logger.debug(f"There is no match in database for {alias}")
            return None
