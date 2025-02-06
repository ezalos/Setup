from datetime import datetime
from pathlib import Path
from typing import List, Optional, Dict
from pydantic import BaseModel, Field

class BackupMetadata(BaseModel):
    """Represents a backup of a dotfile at a specific point in time

    Attributes:
        backup_path (str): Path where the backup is stored
        identifier (str): System identifier where the backup was made
        datetime (str): When the backup was made (format: YYYY-MM-DD_HH:MM)
    """
    backup_path: str
    identifier: str
    datetime: str

class DotFileModel(BaseModel):
    """Represents a dotfile with its configuration and backup history

    A dotfile is a configuration file that needs to be tracked and synced across systems.
    It has a main version in the dotfiles directory and can be deployed as a symlink.

    Attributes:
        alias (str): Name used to identify the dotfile (usually the filename)
        path (str): Path where the dotfile should be deployed in the system
        main (str): Path to the main version in the dotfiles directory
        identifier (str): System identifier where this dotfile is configured
        backups (List[BackupMetadata]): History of backups for this dotfile
    """
    alias: str
    path: str
    main: str
    identifier: str
    backups: List[BackupMetadata] = Field(default_factory=list)

class DevicesData(BaseModel):
    """Represents a system where dotfiles can be deployed

    Attributes:
        identifier (str): Unique identifier for the system (hostname.username)
        home_path (str): Path to the home directory on this system
        dotfiles_dir_path (str): Path to the dotfiles directory on this system
    """
    identifier: str
    home_path: str 
    dotfiles_dir_path: str

class MetaDataDotFiles(BaseModel):
    """Model representing the entire meta.json file containing all dotfiles and devices

    This is the root model that contains all the data needed to manage dotfiles
    across multiple systems.

    Attributes:
        dotfiles (List[DotFileModel]): List of all tracked dotfiles
        devices (Dict[str, DevicesData]): Mapping of system identifiers to their configuration
    """
    dotfiles: List[DotFileModel] = Field(default_factory=list)
    devices: Dict[str, DevicesData] = Field(default_factory=dict)
