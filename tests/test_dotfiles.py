import pytest
from src_dotfiles.config import set_config, config
from pathlib import Path
import shutil
import os
import time
from ezpy_logs.LoggerFactory import LoggerFactory

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

def verify_dotfile_is_added(alias, path):
	dotfile = ManageDotfiles().db.select_by_alias(alias)
	assert Path(path).is_symlink()
	assert Path(dotfile.data.main).exists()

def verify_file_content_matches(file1: Path, file2: Path):
    """Verify that two files have the same content"""
    with open(file1) as f1, open(file2) as f2:
        assert f1.read() == f2.read()

def remove_file_if_exists(path: Path):
    """Remove a file or symlink if it exists"""
    if path.is_symlink():
        os.unlink(path)
    elif path.exists():
        path.unlink()

def get_latest_backup(dotfile) -> Path:
    """Get the path to the most recent backup of a dotfile"""
    assert len(dotfile.data.backups) > 0, "No backups found"
    return Path(dotfile.data.backups[-1].backup_path)

# --------------------------------- Add file --------------------------------- #

@pytest.mark.run(order=1)
def test_add_dotfile_no_alias(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_a"
	alias = ManageDotfiles().add(path=dotfile_path)
	verify_dotfile_is_added(alias, dotfile_path)

@pytest.mark.run(order=2)
def test_add_dotfile_with_alias(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_b"
	alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile")
	assert alias == "b_dotfile"
	verify_dotfile_is_added(alias, dotfile_path)


@pytest.mark.run(order=3)
def test_add_dotfile_alias_exists_no_force(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c"
	alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile")
	assert Path(dotfile_path).exists()
	assert not Path(dotfile_path).is_symlink()
	assert alias is None


@pytest.mark.run(order=4)
def test_add_dotfile_alias_exists_force_different_path(setup_test_environment):
    dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c"
    with pytest.raises(NotImplementedError):
        alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile", force=True)


@pytest.mark.run(order=5)
def test_add_dotfile_alias_exists_force_same_path(setup_test_environment):
	dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_b"
	alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile", force=True)
	assert alias == "b_dotfile"
	verify_dotfile_is_added(alias, dotfile_path)


# -------------------------------- Deploy file ------------------------------- #

@pytest.mark.run(order=6)
def test_deploy_dotfile_with_alias_no_file_before(setup_test_environment):
    # Setup
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_a")
    remove_file_if_exists(dotfile_path)
    assert not dotfile_path.exists()

    # Deploy
    manager = ManageDotfiles()
    manager.deploy("test_dotfile_a")

    # Verify
    assert dotfile_path.is_symlink()
    dotfile = manager.db.select_by_alias("test_dotfile_a")
    assert dotfile is not None
    assert Path(dotfile.data.main).exists()

@pytest.mark.run(order=7)
def test_deploy_dotfile_with_alias_with_file_before(setup_test_environment):
    # Setup
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_b")
    remove_file_if_exists(dotfile_path)
    
    # Create a file with different content
    dotfile_path.write_text("Modified content for testing backup")
    assert dotfile_path.exists()
    assert not dotfile_path.is_symlink()

    # Deploy
    manager = ManageDotfiles()
    manager.deploy("b_dotfile")

    # Verify file is now a symlink
    assert dotfile_path.is_symlink()
    dotfile = manager.db.select_by_alias("b_dotfile")
    assert dotfile is not None

    # Verify backup was created and contains our modified content
    backup_path = get_latest_backup(dotfile)
    assert backup_path.exists()
    assert "Modified content for testing backup" in backup_path.read_text()

@pytest.mark.run(order=8)
def test_deploy_all_dotfiles(setup_test_environment):
    # Setup - remove all files
    manager = ManageDotfiles()
    for dotfile in manager.db.data:
        remove_file_if_exists(Path(dotfile.data.path))
        assert not Path(dotfile.data.path).exists()

    # Deploy all
    manager.deploy()

    # Verify all files are deployed
    for dotfile in manager.db.data:
        path = Path(dotfile.data.path)
        assert path.is_symlink()
        assert Path(dotfile.data.main).exists()

# -------------------------------- Backup tests ------------------------------- #

@pytest.mark.run(order=9)
def test_backup_preserves_content(setup_test_environment):
    """Test that a backup preserves the exact content of the original file."""
    # GIVEN a file with specific content
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c")
    remove_file_if_exists(dotfile_path)
    test_content = "Test content for backup verification\nWith multiple lines\n123"
    dotfile_path.write_text(test_content)

    # WHEN adding it to the system
    manager = ManageDotfiles()
    alias = manager.add(str(dotfile_path), alias="c_dotfile")

    # THEN the backup should match the original content
    dotfile = manager.db.select_by_alias("c_dotfile")
    backup_path = get_latest_backup(dotfile)
    verify_file_content_matches(dotfile_path, backup_path)

@pytest.mark.run(order=10)
def test_backup_creates_unique_files(setup_test_environment):
    """Test that each backup creates a new file with unique content."""
    # GIVEN a dotfile in the system
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c")
    manager = ManageDotfiles()
    dotfile = manager.db.select_by_alias("c_dotfile")
    initial_backup_count = len(dotfile.data.backups)

    # WHEN creating multiple versions
    test_content = "New version for unique backup test"
    remove_file_if_exists(dotfile_path)
    dotfile_path.write_text(test_content)
    manager.deploy("c_dotfile")

    # THEN a new backup should be created
    dotfile = manager.db.select_by_alias("c_dotfile")
    assert len(dotfile.data.backups) == initial_backup_count + 1
    backup_path = get_latest_backup(dotfile)
    assert backup_path.read_text() == test_content

@pytest.mark.run(order=11)
def test_backup_maintains_version_history(setup_test_environment):
    """Test that backups maintain the correct version history."""
    # GIVEN a dotfile and some content versions
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c")
    contents = [
        "First version",
        "Second version\nWith a new line",
        "Third version\nWith more\nlines\n",
    ]
    manager = ManageDotfiles()
    dotfile = manager.db.select_by_alias("c_dotfile")
    initial_backup_count = len(dotfile.data.backups)

    # WHEN creating multiple versions
    for content in contents:
        remove_file_if_exists(dotfile_path)
        dotfile_path.write_text(content)
        manager.deploy("c_dotfile")

    # THEN all versions should be preserved in order
    dotfile = manager.db.select_by_alias("c_dotfile")
    new_backups = dotfile.data.backups[initial_backup_count:]
    assert len(new_backups) == len(contents)
    
    for backup, expected_content in zip(new_backups, contents):
        assert Path(backup.backup_path).read_text() == expected_content

@pytest.mark.run(order=12)
def test_backup_metadata_is_correct(setup_test_environment):
    """Test that backup metadata is correctly recorded."""
    # GIVEN a dotfile to backup
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c")
    test_content = "Content for metadata test"
    manager = ManageDotfiles()
    
    # WHEN creating a backup
    remove_file_if_exists(dotfile_path)
    dotfile_path.write_text(test_content)
    manager.deploy("c_dotfile")
    
    # THEN the metadata should be correct
    dotfile = manager.db.select_by_alias("c_dotfile")
    backup = dotfile.data.backups[-1]
    assert backup.identifier == config.identifier
    assert len(backup.datetime) > 0  # Has a timestamp
    assert Path(backup.backup_path).exists()
    assert Path(backup.backup_path).read_text() == test_content
