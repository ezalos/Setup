# File operations
import os
import shutil
from datetime import datetime
from src_dotfiles.config import config
from pathlib import Path
from ezpy_logs.LoggerFactory import LoggerFactory
from src_dotfiles.models import DotFileModel, BackupMetadata
from typing import Optional, List

logger = LoggerFactory.getLogger(__name__)

def get_time() -> str:
    now = datetime.now()
    current_time = now.strftime("%Y-%m-%d_%H:%M")
    return current_time

class DotFile:
    def __init__(self, path: str,
                alias: Optional[str] = None,
                identifier: Optional[str] = None,
                backups: Optional[List[BackupMetadata]] = None,
                main: Optional[str] = None):
        """DotFile allows to backup a dotfile or deploy it.
        It is an important element of my personal backup system.

        Args:
            path (str): Path to system .file
            alias (Optional[str]): .file name in the dotfiles directory. Defaults to original filename.
            identifier (Optional[str]): Naming the system, it's the 'computer + user'. Defaults to config.identifier.
            backups (Optional[List[BackupMetadata]]): List of backup metadata. Defaults to empty list.
            main (Optional[str]): Should be used as main .file. Defaults to None.
        """
        self.path = path
        self.alias = alias if alias is not None else Path(self.path).name
        self.main = main if main is not None else Path(config.dotfiles_dir).joinpath(self.alias).as_posix()
        self.backups = backups if backups is not None else []
        self.identifier = identifier if identifier is not None else config.identifier

    def add_file(self, use_as_main=True, deploy=True):
        logger.info(f'Adding {self.alias} from {self.path}')

        if os.path.islink(self.path):
            logger.warning(f'Error: {self.alias} is already a symlink')
            return
        self.backup()
        if use_as_main:
            self.copy_as_main()
        if deploy:
            self.deploy()

    def deploy(self):
        """[summary]
            Deploy the dotfile in the system.
            /!\ Will delete the file -> should be used with add()
        """
        dirs = os.path.dirname(self.path)
        logger.debug(f'Extracting dir part of src: {dirs}')
        if os.path.exists(self.path):
            logger.debug(f'Deleting {self.path}')
            # os.remove(self.path)
        # There is pbm with remove
        # sometimes file is not seen
        # with above if.
        # TODO: clean this trick
        try:
            os.remove(self.path)
        except Exception as e:
            logger.debug(f"Could not remove {self.path}: {str(e)}")
            pass
        if not os.path.exists(dirs):
            logger.info(f'{dirs} does not exist: creating it')
            os.makedirs(dirs)
        main = Path(config.project_path).joinpath(self.main).as_posix()
        logger.info(f"Symlink created {self.path} -> {main}")
        os.symlink(main, self.path)

    def backup_add_meta_data(self, backup_path: str, identifier: str, stime: str) -> None:
        meta = BackupMetadata(
            backup_path=backup_path,
            identifier=identifier,
            datetime=stime
        )
        self.backups.append(meta)

    def backup(self):
        if os.path.exists(self.path):
            if os.path.islink(self.path):
                logger.warning(f"File is already a symlink, it will not be backup")
                return
            stime = get_time()
            backup_path = Path(config.project_path).joinpath(config.backup_dir).joinpath(
                            self.alias \
                            + '_' \
                            + config.identifier \
                            + '_' \
                            + stime
            ).as_posix()
            logger.debug(f"{self.path = }")
            logger.debug(f"{backup_path = }")
            
            shutil.copy(self.path, backup_path)
            logger.info(f"Backed up as {backup_path}")
            self.backup_add_meta_data(backup_path, config.identifier, stime)
        else:
            logger.warning(f"{self.path} does not exist, no backup will be done")

    def copy_as_main(self, force=False):
        logger.info(f"Copying {self.path} as main to {self.main}")
        if os.path.exists(self.main):
            logger.warning(f'File {self.path} already exist in Setup')
            if not force:
                return
        if os.path.exists(self.path):
            shutil.copy(self.path, self.main)
            logger.info(f'{self.main} has been added as main for {self.path}')

    def to_db(self) -> dict:
        model = DotFileModel(
            alias=self.alias,
            path=self.path,
            main=self.main,
            identifier=self.identifier,
            backups=self.backups
        )
        return model.model_dump()

    def from_db(self, data: dict) -> None:
        model = DotFileModel.model_validate(data)
        self.__init__(
            path=model.path,
            alias=model.alias,
            identifier=model.identifier,
            backups=model.backups,
            main=model.main
        )

    def __str__(self) -> str:
        msg = f"{self.alias} @{self.identifier}\n"
        msg += f"{self.path} -> {self.main}\n"
        for b in self.backups:
            msg += f"\t@{b.identifier} done at {b.datetime}\n"
            msg += f"\t-> {b.backup_path}\n"
        return msg
