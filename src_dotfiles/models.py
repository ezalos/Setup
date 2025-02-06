from datetime import datetime
from pathlib import Path
from typing import List, Optional
from pydantic import BaseModel, Field

class BackupMetadata(BaseModel):
    backup_path: str
    identifier: str
    datetime: str

class DotFileModel(BaseModel):
    alias: str
    path: str
    main: str
    identifier: str
    backups: List[BackupMetadata] = Field(default_factory=list)

class MetaDataDotFiles(BaseModel):
    """Model representing the entire meta.json file containing all dotfiles"""
    dotfiles: List[DotFileModel] = Field(default_factory=list) 