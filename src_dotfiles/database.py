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
    """Manages the collection of dotfiles and their metadata.
    
    This class handles loading and saving the metadata file, and provides
    access to individual dotfiles. It maintains both the raw metadata (through
    Pydantic models) and the operational DotFile instances.
    """
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

    def create_dotfile(self, path: str, alias: Optional[str] = None) -> DotFile:
        """Create a new DotFile instance with appropriate model

        Args:
            path (str): Path where the dotfile should exist in the system
            alias (Optional[str]): Custom alias for the dotfile. Default: filename from path

        Returns:
            DotFile: New DotFile instance
        """
        model = DotFileModel(
            path=path,
            alias=alias if alias is not None else Path(path).name,
            main=Path(config.dotfiles_dir).joinpath(
                alias if alias is not None else Path(path).name
            ).as_posix(),
            identifier=config.identifier,
            backups=[]
        )
        return DotFile(model)

    def load_all(self) -> List[DotFile]:
        """Converts the metadata into usable DotFile objects

        Returns:
            List[DotFile]: List of DotFile objects
        """
        return [DotFile(model) for model in self.metadata.dotfiles]

    def save_all(self) -> None:
        """Saves all dotfile data to the metadata file"""
        self.metadata.dotfiles = [d.data for d in self.data]
        
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
        selection = [d for d in self.data if d.data.alias == alias]
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
