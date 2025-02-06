# File operations
import os
import shutil
from datetime import datetime
from src_dotfiles.config import config
from pathlib import Path
from ezpy_logs.LoggerFactory import LoggerFactory
from src_dotfiles.models import DotFileModel, BackupMetadata
from src_dotfiles.models import DevicesData

logger = LoggerFactory.getLogger(__name__)

def get_time() -> str:
    """Get current time in the format used for backups

    Returns:
        str: Current time in format YYYY-MM-DD_HH:MM:SS.NNNNNN
    """
    now = datetime.now()
    current_time = now.strftime("%Y-%m-%d_%H:%M:%S.%f")
    return current_time

class DotFile:
    """Operations wrapper for a dotfile in the system.
    
    This class handles the file system operations for a dotfile, such as:
    - Backing up the existing file before modifications
    - Deploying the dotfile as a symlink
    - Managing the main copy in the dotfiles directory

    The state is stored in the provided DotFileModel instance.
    """
    def __init__(self, data: DotFileModel):
        """Initialize with a DotFileModel instance.

        Args:
            data (DotFileModel): The model containing the dotfile's state
        """
        self.data = data

    def add_file(self, use_as_main: bool = True, deploy: bool = True) -> None:
        """Add a new dotfile to be managed.
        
        Args:
            use_as_main (bool): Whether to copy current file as main version
            deploy (bool): Whether to deploy the symlink after adding
        """
        logger.info(f'Adding {self.data.alias} from {self.data.path}')

        if os.path.islink(self.data.path):
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
        dirs = os.path.dirname(self.data.path)
        logger.debug(f'Extracting dir part of src: {dirs}')
        
        try:
            if os.path.exists(self.data.path):
                logger.debug(f'Deleting {self.data.path}')
                os.remove(self.data.path)
        except Exception as e:
            logger.debug(f"Could not remove {self.data.path}: {str(e)}")

        if not os.path.exists(dirs):
            logger.info(f'{dirs} does not exist: creating it')
            os.makedirs(dirs)

        main = Path(config.project_path).joinpath(self.data.main).as_posix()
        logger.info(f"Symlink created {self.data.path} -> {main}")
        os.symlink(main, self.data.path)

    def backup(self) -> None:
        """Create a backup of the current file if it exists and is not a symlink."""
        if not os.path.exists(self.data.path):
            logger.warning(f"{self.data.path} does not exist, no backup will be done")
            return

        if os.path.islink(self.data.path):
            logger.warning(f"File is already a symlink, it will not be backup")
            return

        stime = get_time()
        backup_path = Path(config.project_path).joinpath(config.backup_dir).joinpath(
            f"{self.data.alias}_{config.identifier}_{stime}"
        ).as_posix()

        logger.debug(f"{self.data.path = }")
        logger.debug(f"{backup_path = }")
        
        shutil.copy(self.data.path, backup_path)
        logger.info(f"Backed up as {backup_path}")
        
        self.data.backups.append(BackupMetadata(
            backup_path=backup_path,
            identifier=config.identifier,
            datetime=stime
        ))

    def copy_as_main(self, force: bool = False) -> None:
        """Copy the current file as the main version.
        
        Args:
            force (bool): Whether to overwrite existing main file
        """
        logger.info(f"Copying {self.data.path} as main to {self.data.main}")
        if os.path.exists(self.data.main):
            logger.warning(f'File {self.data.path} already exist in Setup')
            if not force:
                return

        if os.path.exists(self.data.path):
            shutil.copy(self.data.path, self.data.main)
            logger.info(f'{self.data.main} has been added as main for {self.data.path}')

    def translate_to_device(self, original_device: DevicesData, target_device: DevicesData) -> "DotFile":
        """Create a new DotFile instance with paths translated for the target device.
        
        Args:
            original_device: Device data where the paths are currently based
            target_device: Device data where we want to translate paths to
            
        Returns:
            New DotFile instance with translated paths for target device
        """
        logger.debug(f"Translating paths from {original_device.identifier} to {target_device.identifier}")
        logger.debug(f"Original path: {self.data.path}")
        logger.debug(f"Original main: {self.data.main}")

        # Translate system path (e.g., /home/user/.zshrc -> /Users/user/.zshrc)
        new_path = self.data.path
        if original_device.home_path in new_path:
            new_path = new_path.replace(original_device.home_path, target_device.home_path, 1)
        else:
            # If path doesn't contain original home, assume it's relative to home
            new_path = str(Path(target_device.home_path) / self.data.path)
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
            path=new_path,
            main=new_main,
            identifier=target_device.identifier,
            backups=[]  # Reset backups as they're device-specific
        )
        
        return DotFile(new_model)

    def __str__(self) -> str:
        msg = f"{self.data.alias} @{self.data.identifier}\n"
        msg += f"{self.data.path} -> {self.data.main}\n"
        for b in self.data.backups:
            msg += f"\t@{b.identifier} done at {b.datetime}\n"
            msg += f"\t-> {b.backup_path}\n"
        return msg
