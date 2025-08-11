# File operations
import os
import shutil
from datetime import datetime
from src_dotfiles.config import config
from pathlib import Path
from ezpy_logs.LoggerFactory import LoggerFactory
from src_dotfiles.models import DotFileModel, BackupMetadata, Identifier, DeployedDotFile, DevicesData

logger = LoggerFactory.getLogger(__name__)
DATETIME_FORMAT = "%Y-%m-%d_%H:%M:%S.%f"

def get_time() -> str:
    """Get current time in the format used for backups

    Returns:
        str: Current time in format YYYY-MM-DD_HH:MM:SS.NNNNNN
    """
    now = datetime.now()
    current_time = now.strftime(DATETIME_FORMAT)
    return current_time

class DotFile:
    """Operations wrapper for a dotfile in the system.
    
    This class handles the file system operations for a dotfile, such as:
    - Backing up the existing file before modifications
    - Deploying the dotfile as a symlink
    - Managing the main copy in the dotfiles directory

    The state is stored in the provided DotFileModel instance.
    """
    def __init__(self, data: DotFileModel, identifier: Identifier = config.identifier):
        """Initialize with a DotFileModel instance.

        Args:
            data (DotFileModel): The model containing the dotfile's state
            identifier (str): The identifier of the device where the dotfile is deployed
        """
        self.data = data
        self.identifier = identifier

    def add_file(self, use_as_main: bool = True, deploy: bool = True) -> None:
        """Add a new dotfile to be managed.
        
        Args:
            use_as_main (bool): Whether to copy current file as main version
            deploy (bool): Whether to deploy the symlink after adding
        """
        logger.info(f'Adding {self.data.alias} from {self.data.deploy[self.identifier].deploy_path}')

        if os.path.islink(self.data.deploy[self.identifier].deploy_path):
            logger.warning(f'Error: {self.data.alias} is already a symlink')
            return
        self.backup()
        if use_as_main:
            self.copy_as_main()
        if deploy:
            self.deploy()

    def deploy(self) -> None:
        """Deploy the dotfile in the system.
        
        Creates a symlink from the system path to the main version.
        Will delete any existing file at the target path.
        """
        dirs = os.path.dirname(self.data.deploy[self.identifier].deploy_path)
        logger.debug(f'Extracting dir part of src: {dirs}')
        
        try:
            if os.path.exists(self.data.deploy[self.identifier].deploy_path):
                logger.debug(f'Deleting {self.data.deploy[self.identifier].deploy_path}')
                os.remove(self.data.deploy[self.identifier].deploy_path)
        except Exception as e:
            logger.debug(f"Could not remove {self.data.deploy[self.identifier].deploy_path}: {str(e)}")

        if not os.path.exists(dirs):
            logger.info(f'{dirs} does not exist: creating it')
            os.makedirs(dirs)

        main = Path(config.project_path).joinpath(self.data.main).as_posix()
        logger.info(f"Symlink created {self.data.deploy[self.identifier].deploy_path} -> {main}")
        os.symlink(main, self.data.deploy[self.identifier].deploy_path)

    def backup(self) -> None:
        """Create a backup of the current file if it exists and is not a symlink."""
        if not os.path.exists(self.data.deploy[self.identifier].deploy_path):
            logger.warning(f"{self.data.deploy[self.identifier].deploy_path} does not exist, no backup will be done")
            return

        if os.path.islink(self.data.deploy[self.identifier].deploy_path):
            logger.warning(f"File is already a symlink, it will not be backup")
            return

        stime = get_time()
        backup_path = Path(config.project_path).joinpath(config.backup_dir).joinpath(
            f"{self.data.alias}_{config.identifier}_{stime}"
        ).as_posix()

        logger.debug(f"{self.data.deploy[self.identifier].deploy_path = }")
        logger.debug(f"{backup_path = }")
        
        shutil.copy(self.data.deploy[self.identifier].deploy_path, backup_path)
        logger.info(f"Backed up as {backup_path}")
        
        self.data.deploy[self.identifier].backups.append(BackupMetadata(
            backup_path=backup_path,
            datetime=stime
        ))

    def copy_as_main(self, force: bool = False) -> None:
        """Copy the current file as the main version.
        
        Args:
            force (bool): Whether to overwrite existing main file
        """
        logger.info(f"Copying {self.data.deploy[self.identifier].deploy_path} as main to {self.data.main}")
        if os.path.exists(self.data.main):
            logger.warning(f'File {self.data.deploy[self.identifier].deploy_path} already exist in Setup')
            if not force:
                return

        if os.path.exists(self.data.deploy[self.identifier].deploy_path):
            shutil.copy(self.data.deploy[self.identifier].deploy_path, self.data.main)
            logger.info(f'{self.data.main} has been added as main for {self.data.deploy[self.identifier].deploy_path}')

    def translate_to_device(self, original_device: DevicesData, target_device: DevicesData) -> "DotFile":
        """Create a new DotFile instance with paths translated for the target device.
        
        Args:
            original_device: Device data where the paths are currently based
            target_device: Device data where we want to translate paths to
            
        Returns:
            New DotFile instance with translated paths for target device
        """
        logger.debug(f"Translating paths from {original_device.identifier} to {target_device.identifier}")
        assert original_device.identifier in self.data.deploy.keys()
        logger.debug(f"Original path: {self.data.deploy[original_device.identifier].deploy_path}")
        logger.debug(f"Original main: {self.data.main}")

        # Translate system path (e.g., /home/user/.zshrc -> /Users/user/.zshrc)
        new_path = self.data.deploy[original_device.identifier].deploy_path
        if original_device.home_path in new_path:
            new_path = new_path.replace(original_device.home_path, target_device.home_path, 1)
        else:
            # If path doesn't contain original home, assume it's relative to home
            new_path = str(Path(target_device.home_path) / self.data.deploy[original_device.identifier].deploy_path)
        logger.debug(f"Translated path: {new_path}")

        # Translate main path (e.g., dotfiles/.zshrc -> test_dotfiles/.zshrc)
        new_main = self.data.main
        if original_device.dotfiles_dir_path in new_main:
            new_main = new_main.replace(
                original_device.dotfiles_dir_path,
                target_device.dotfiles_dir_path,
                1
            )
        logger.debug(f"Translated main: {new_main}")

        # Create new model with translated paths
        new_model = DotFileModel(
            alias=self.data.alias,
            main=new_main,
            deploy={
                target_device.identifier: DeployedDotFile(
                    deploy_path=new_path,
                    backups=[]
                )
            }
        )
        
        return DotFile(new_model, target_device.identifier)

    def __str__(self) -> str:
        msg = f"{self.identifier}\n"
        msg += f"{self.data.alias} : {self.data.main}\n"
        for identifier, deploy in self.data.deploy.items():
            msg += f"\t@{identifier} : {deploy.deploy_path}\n"
            for b in deploy.backups:
                msg += f"\t\t{b.datetime} -> {b.backup_path}\n"
        return msg
