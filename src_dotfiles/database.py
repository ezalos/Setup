from src_dotfiles.config import config
import json
from pathlib import Path
from ezpy_logs.LoggerFactory import LoggerFactory
from typing import List, Optional
from src_dotfiles.models import DotFileModel, MetaDataDotFiles
from src_dotfiles.DotFile import DotFile

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


class Dependencies:
    def __init__(self):
        self.test: bool = False
        logger.debug(f"{config.depedencies_path = }")
        logger.debug(f"{config.dotfiles_dir = }")
        self.path: str = config.depedencies_path
        self.path_test: str = config.dotfiles_dir + "test_" + "meta.json"
        self.metadata: MetaDataDotFiles = self.load()
        self.data: List[DotFile] = self.load_all()

    def get_db_path(self) -> Path:
        """Get the path to the database file

        Returns:
            Path: Path to the database file
        """
        dest = self.path_test if self.test else self.path
        return Path(config.project_path).joinpath(dest)

    def load(self) -> MetaDataDotFiles:
        """Loads the db in memory and validates it

        Returns:
            MetaDataDotFiles: Validated metadata from file
        """
        db_path = self.get_db_path()
        logger.debug(f"{db_path = }")

        if not db_path.exists():
            return MetaDataDotFiles()

        with open(db_path) as f:
            data = f.read()
            # If file is empty, return empty model
            if not data.strip():
                return MetaDataDotFiles()
            return MetaDataDotFiles.model_validate_json(data)

    def load_all(self) -> List[DotFile]:
        """Converts the raw_db data in usable objects

        Returns:
            List[DotFile]: List of DotFile objects
        """
        data = []
        for dotfile_model in self.metadata.dotfiles:
            dot = DotFile(dotfile_model.path)
            dot.from_db(dotfile_model.model_dump())
            logger.debug(f"Loaded {dot.path}")
            data.append(dot)
        return data

    def save_all(self) -> None:
        """Converts dotfile objects to raw_db data and saves them"""
        self.metadata.dotfiles = []
        for d in self.data:
            logger.debug(f"Adding {d.alias = } {d.path = } to future backup")
            model = DotFileModel.model_validate(d.to_db())
            self.metadata.dotfiles.append(model)
        
        db_path = self.get_db_path()
        logger.info(f"Saving to {db_path}")
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with open(db_path, 'w') as f:
            f.write(self.metadata.model_dump_json(indent=4))

    def select_by_alias(self, alias: str) -> Optional[DotFile]:
        """Select a dotfile by its alias

        Args:
            alias (str): The alias to search for

        Returns:
            Optional[DotFile]: The found DotFile or None if not found
        """
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
