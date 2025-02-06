import pytest
from src_dotfiles.config import set_config, config
from pathlib import Path
import shutil

@pytest.fixture(scope="session", autouse=True)
def setup_test_environment():
    print("\nInitializing test environment (this should happen only once)...")

    set_config(dotfiles_dir="test_dotfiles")
    shutil.rmtree(config.dotfiles_dir, ignore_errors=True)
    set_config(dotfiles_dir="test_dotfiles")
    Path(config.dotfiles_dir).mkdir(parents=True, exist_ok=True)

    TEST_DATA_ORIGINAL = Path("data/original")
    TEST_DATA_TMP = Path("data/test_data")

    shutil.rmtree(TEST_DATA_TMP, ignore_errors=True)
    shutil.copytree(TEST_DATA_ORIGINAL, TEST_DATA_TMP)
    print("Test environment setup complete!")

    return {
		"TEST_DATA_ORIGINAL": TEST_DATA_ORIGINAL,
		"TEST_DATA_TMP": TEST_DATA_TMP
	}

from src_dotfiles.__main__ import ManageDotfiles

def verify_backup_is_created(alias, path):
	md = ManageDotfiles()
	dotfile = md.db.select_by_alias(alias)
	assert Path(dotfile.backup_path).exists()

def verify_dotfile_is_added(alias, path):
	dotfile = ManageDotfiles().db.select_by_alias(alias)
	assert Path(path).is_symlink()
	assert Path(dotfile.main).exists()

# --------------------------------- Add file --------------------------------- #

def test_add_dotfile_no_alias(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_a"
	alias = ManageDotfiles().add(path=dotfile_path)
	verify_dotfile_is_added(alias, dotfile_path)

def test_add_dotfile_with_alias(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_b"
	alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile")
	assert alias == "b_dotfile"
	verify_dotfile_is_added(alias, dotfile_path)


def test_add_dotfile_alias_exists_no_force(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c"
	alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile")
	assert Path(dotfile_path).exists()
	assert not Path(dotfile_path).is_symlink()
	assert alias is None


def test_add_dotfile_alias_exists_force_different_path(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c"
	with pytest.raises(NotImplementedError):
		alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile", force=True)


def test_add_dotfile_alias_exists_force_same_path(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_b"
	alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile", force=True)
	assert alias == "b_dotfile"
	verify_dotfile_is_added(alias, dotfile_path)
	# verify_backup_is_created(alias, dotfile_path)


# # -------------------------------- Deploy file ------------------------------- #

# def test_deploy_dotfile_with_alias_no_file_before():
# 	pass

# def test_deploy_dotfile_with_alias_with_file_before():
# 	# Check backup
# 	pass

# def test_deploy_all_dotfiles():
# 	pass
