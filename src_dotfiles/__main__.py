#!/usr/bin/env python3

import fire
from src_dotfiles.database import Dependencies
from src_dotfiles.config import config
from src_dotfiles.models import DeployedDotFile
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

    def add(self, path: str, alias: Optional[str] = None, force: bool = False, only_device: Optional[str] = None) -> Optional[str]:
        """Add a new dotfile to be managed by the system.

        Args:
            path (str): Path to the dotfile to add
            alias (Optional[str]): Custom alias for the dotfile. If not provided, will be generated from filename.
            force (bool): Whether to force add if alias already exists.
            only_device (Optional[str]): If set, restrict this dotfile to the given device identifier.

        Returns:
            Optional[str]: Alias of the added dotfile if successful, None if failed

        Raises:
            NotImplementedError: If force=True and trying to add different path for existing alias
        """
        logger.debug(f"{path = } {alias = } {force = } {only_device = }")

        new_dot_file = self.db.create_dotfile(path, alias, only_device=only_device)

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
            logger.debug(f"{current_dot_file.data = }")
            logger.debug(f"{new_dot_file.data = }")
            if current_dot_file.data.deploy[new_dot_file.identifier].deploy_path == new_dot_file.data.deploy[new_dot_file.identifier].deploy_path:
                logger.debug("Argument path is the same as the one in the system")
                # Path resolution is way more complex than this :/
                new_dot_file.backup()
                new_dot_file.deploy()
                self.db.data.append(new_dot_file)
                self.db.save_all()
                return new_dot_file.data.alias
            else:
                logger.error("Argument path is different from the one in the system")
                logger.error(f"{current_dot_file.data.deploy[current_dot_file.identifier].deploy_path} != {new_dot_file.data.deploy[new_dot_file.identifier].deploy_path}")
                raise NotImplementedError

    def extend_to(self, alias: str, device: str, deploy_path: Optional[str] = None) -> None:
        """Extend an existing dotfile to a new device.

        Adds `device` to the dotfile's `deploy` map and, if `only_devices` is set,
        appends `device` to that list too. Does NOT copy files to the target
        device — run `deploy` on the target host afterwards (typically via
        setup_sync_down + `python -m src_dotfiles deploy`).

        Args:
            alias (str): Alias of the dotfile to extend (must already exist).
            device (str): Device identifier to add (e.g. "TinyButMighty.ezalos").
            deploy_path (Optional[str]): Where the dotfile should land on the
                target device. If omitted, reuses the deploy_path of an existing
                deploy entry — fine when the home_path is identical on both
                devices, wrong otherwise.
        """
        model = self.db.metadata.dotfiles.get(alias)
        if model is None:
            logger.error(f"No dotfile with alias {alias!r} in registry")
            return

        if deploy_path is None:
            if not model.deploy:
                logger.error(f"{alias} has no existing deploy entries; --deploy-path is required")
                return
            sample_device, sample_entry = next(iter(model.deploy.items()))
            deploy_path = sample_entry.deploy_path
            logger.info(f"Defaulting deploy_path to {deploy_path!r} (copied from {sample_device})")

        if device in model.deploy:
            existing = model.deploy[device].deploy_path
            if existing == deploy_path:
                logger.info(f"{alias} already deploys to {device} at {deploy_path}; no change to deploy map")
            else:
                logger.error(
                    f"{alias} already has a deploy entry for {device} at {existing!r} "
                    f"which differs from requested {deploy_path!r}; refusing to overwrite"
                )
                return
        else:
            model.deploy[device] = DeployedDotFile(deploy_path=deploy_path, backups=[])
            logger.info(f"Added deploy entry for {device}: {deploy_path}")

        if model.only_devices is not None and device not in model.only_devices:
            model.only_devices.append(device)
            logger.info(f"Appended {device} to only_devices")
        elif model.only_devices is not None:
            logger.info(f"{device} already in only_devices")

        self.db.metadata.dotfiles[alias] = model
        self.db.save_all()
        logger.info(f"Saved. Now run `python -m src_dotfiles deploy --alias {alias}` on {device}.")

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