# File operations
import os
import shutil
from datetime import datetime
from src_dotfiles.config import config
from pathlib import Path
from ezpy_logs.LoggerFactory import LoggerFactory

logger = LoggerFactory.getLogger(__name__)

def get_time():
    now = datetime.now()
    current_time = now.strftime("%Y-%m-%d_%H:%M")
    return current_time

class DotFile():
    def __init__(self, path: str,
                alias: str=None, identifier:str=config.identifier,
                backups: list=[], main: str=None):
        """[summary]
            DotFile allows to backup a dotfile or deploy it.
                It is an important element of my personal backup system

                Most parameters are just for allowing an easy load from database.

            Args:
                path (str): [Path to system .file]
                alias (str, optional): [.file name in the dotfiles directory]. Defaults to original filename.
                identifier (str, optional): [Naming the system, it's the 'computer + user']. Defaults to config.identifier.
                backups (str, optional): [path + id for the backups]. Defaults to None.
                main (str, optional): [Should be used as main .file]. Defaults to None.
        """
        self.path = path
        # TODO: create alias suggestor one level up
        if alias == None:
            self.alias = Path(self.path).name
        else:
            self.alias = alias
        if main == None: 
            self.main =  Path(config.dotfiles_dir).joinpath(self.alias).as_posix()
        else:
            self.main = main
        self.backups = backups
        if identifier == None:
            identifier = config.identifier
        self.identifier = identifier

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

    def backup_add_meta_data(self, backup_path, identifier, stime):
        meta = {
            'backup_path': backup_path,
            'identifier': identifier,
            'datetime': stime,
        }
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

    def to_db(self):
        self.dict = {
                'alias': self.alias,
                'path': self.path,
                'main': self.main,
                'identifier': self.identifier,
                'backups': self.backups,
        }
        return self.dict

    def from_db(self, data):
        alias = data['alias']
        main = data['main']
        path = data['path']
        backups = data['backups']
        identifier = data['identifier']
        self.__init__(path, alias=alias, identifier=identifier, backups=backups, main=main)

    def __str__(self):
        # return str(self.to_db())
        msg = f"{self.alias} @{self.identifier}\n"
        msg += f"{self.path} -> {self.main}\n"
        for b in self.backups:
            msg += f"\t@{b['identifier']} done at {b['datetime']}\n"
            msg += f"\t-> {b['backup_path']}\n"
        return msg
