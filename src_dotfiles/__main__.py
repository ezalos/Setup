#!/usr/bin/env python3

import fire
from src_dotfiles.database import Dependencies
from src_dotfiles.config import config
from src_dotfiles.DotFile import DotFile
from ezpy_logs.LoggerFactory import LoggerFactory
from typing import Optional

LoggerFactory.setup_LoggerFactory()
logger = LoggerFactory.getLogger(__name__)

def path_security_check(path: str) -> bool:
    if not path.startswith(config.home):
        logger.warning(f"/!\\ CAREFULL -> Path {path} do not start by {config.home}")
        logger.warning("\tCurrent path resolution might cause a lot of problems")
        if 'y' != input("If you are sure to continue: enter 'y':"):
            logger.info("Exiting...")
            return True
    return False

class ManageDotfiles:
    def __init__(self):
        self.db = Dependencies()

    def add(self, path: str, alias: Optional[str] = None, force: bool = False) -> Optional[str]:
        """Add a new dotfile to be managed by the system.

        Args:
            path (str): Path to the dotfile to add
            alias (Optional[str]): Custom alias for the dotfile. If not provided, will be generated from filename.
            force (bool): Whether to force add if alias already exists.

        Returns:
            Optional[str]: Alias of the added dotfile if successful, None if failed
            
        Raises:
            NotImplementedError: If force=True and trying to add different path for existing alias
        """
        new_dot_file = self.db.create_dotfile(path, alias)

        current_dot_file = self.db.select_by_alias(new_dot_file.data.alias)
        if not current_dot_file:
            logger.info(f"Alias {new_dot_file.data.alias} does not exist in the system")
            new_dot_file.add_file()
            self.db.data.append(new_dot_file)
            self.db.save_all()
            return new_dot_file.data.alias
        else:       
            if current_dot_file and not force:
                logger.warning(f"Alias {new_dot_file.data.alias} already exists in the system, and force is not set")
                return None
            logger.info(f"Alias {current_dot_file.data.alias} already exists in the system, and force is set")
            if current_dot_file.data.path == new_dot_file.data.path:
                logger.debug("Argument path is the same as the one in the system")
                # Path resolution is way more complex than this :/
                new_dot_file.backup()
                new_dot_file.deploy()
                self.db.data.append(new_dot_file)
                self.db.save_all()
                return new_dot_file.data.alias
            else:
                logger.error("Argument path is different from the one in the system")
                logger.error(f"{current_dot_file.data.path} != {new_dot_file.data.path}")
                raise NotImplementedError

    def deploy(self, alias: Optional[str] = None) -> None:
        """Deploy dotfiles to the system.

        Args:
            alias (Optional[str]):  Alias of the dotfile to deploy. 
                                    If not provided, will deploy all dotfiles.
        """
        if alias == None:
            logger.info("Deploying all dotfiles")
            for dot_file in self.db.data:
                dot_file.backup()
                dot_file.deploy()
        else:
            dot_file = self.db.select_by_alias(alias)
            if dot_file is None:
                logger.warning(f"There is no match in database for {alias}")
                return None
            logger.info(f"Deploying {alias}")
            dot_file.backup()
            dot_file.deploy()
        self.db.save_all()

if __name__ == "__main__":
    fire.Fire(ManageDotfiles)