import pytest
from src_dotfiles.config import set_config, config
from pathlib import Path
import shutil
import os
import time
from ezpy_logs.LoggerFactory import LoggerFactory
from src_dotfiles.__main__ import ManageDotfiles
from src_dotfiles.database import Dependencies
from src_dotfiles.models import DevicesData, DotFileModel, DeployedDotFile, MetaDataDotFiles
from src_dotfiles.DotFile import get_time, DATETIME_FORMAT, DotFile
from datetime import datetime

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
    identifier = dotfile.identifier
    assert len(dotfile.data.deploy[identifier].backups) > 0, "No backups found"
    return Path(dotfile.data.deploy[identifier].backups[-1].backup_path)

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


# @pytest.mark.run(order=4)
# def test_add_dotfile_alias_exists_force_different_path(setup_test_environment):
#     dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c"
#     with pytest.raises(NotImplementedError):
#         alias = ManageDotfiles().add(path=dotfile_path, alias="b_dotfile", force=True)
#         # verify_dotfile_is_added(alias, dotfile_path)



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
        identifier = dotfile.identifier
        remove_file_if_exists(Path(dotfile.data.deploy[identifier].deploy_path))
        assert not Path(dotfile.data.deploy[identifier].deploy_path).exists()

    # Deploy all
    manager.deploy()

    # Verify all files are deployed
    for dotfile in manager.db.data:
        identifier = dotfile.identifier
        path = Path(dotfile.data.deploy[identifier].deploy_path)
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
    identifier = dotfile.identifier
    initial_backup_count = len(dotfile.data.deploy[identifier].backups)

    # WHEN creating multiple versions
    test_content = "New version for unique backup test"
    remove_file_if_exists(dotfile_path)
    dotfile_path.write_text(test_content)
    manager.deploy("c_dotfile")

    # THEN a new backup should be created
    dotfile = manager.db.select_by_alias("c_dotfile")
    assert len(dotfile.data.deploy[identifier].backups) == initial_backup_count + 1
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
    identifier = dotfile.identifier
    initial_backup_count = len(dotfile.data.deploy[identifier].backups)

    # WHEN creating multiple versions
    for content in contents:
        remove_file_if_exists(dotfile_path)
        dotfile_path.write_text(content)
        manager.deploy("c_dotfile")

    # THEN all versions should be preserved in order
    dotfile = manager.db.select_by_alias("c_dotfile")
    new_backups = dotfile.data.deploy[identifier].backups[initial_backup_count:]
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

    t_0 = get_time()
    
    # WHEN creating a backup
    remove_file_if_exists(dotfile_path)
    dotfile_path.write_text(test_content)
    manager.deploy("c_dotfile")

    t_1 = get_time()
    
    # THEN the metadata should be correct
    dotfile = manager.db.select_by_alias("c_dotfile")
    identifier = dotfile.identifier
    backup = dotfile.data.deploy[identifier].backups[-1]
    assert len(backup.datetime) > 0  # Has a timestamp
    assert Path(backup.backup_path).exists()
    assert Path(backup.backup_path).read_text() == test_content
    assert datetime.strptime(t_0, DATETIME_FORMAT) <= datetime.strptime(backup.datetime, DATETIME_FORMAT) <= datetime.strptime(t_1, DATETIME_FORMAT)

# -------------------------------- Device Tests ------------------------------- #

@pytest.mark.run(order=13)
def test_device_data_is_stored(setup_test_environment):
    """Test that device data is stored in metadata."""
    # GIVEN a fresh database
    manager = ManageDotfiles()
    
    # THEN the current device should be in metadata
    assert config.identifier in manager.db.metadata.devices
    device = manager.db.metadata.devices[config.identifier]
    assert device.identifier == config.identifier
    assert device.home_path == config.home
    assert device.dotfiles_dir_path == config.dotfiles_dir

@pytest.mark.run(order=14)
def test_deploy_to_different_device(setup_test_environment):
    """Test deploying a dotfile to a different device."""
    # GIVEN a dotfile from one device
    original_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_c")
    manager = ManageDotfiles()
    dotfile = manager.db.select_by_alias("c_dotfile")
    
    # WHEN translating to a new device
    new_device = DevicesData(
        identifier="test_device",
        home_path="/home/test_user",
        dotfiles_dir_path="test_dotfiles_new"
    )
    manager.db.metadata.devices["test_device"] = new_device
    
    translated = dotfile.translate_to_device(config.device_data, new_device)

    # THEN paths should be correctly translated
    assert translated.identifier == "test_device"
    assert "test_device" in translated.data.deploy.keys()
    assert translated.data.deploy[translated.identifier].deploy_path.startswith("/home/test_user")
    assert "test_dotfiles_new" in translated.data.main
    assert len(translated.data.deploy[translated.identifier].backups) == 0  # Backups don't transfer between devices

@pytest.mark.run(order=15)
def test_load_from_different_device(setup_test_environment):
    """Test loading dotfiles from a different device."""
    # GIVEN a database with a dotfile from another device
    manager = ManageDotfiles()
    new_identifier = "other_device"
    other_device = DevicesData(
        identifier=new_identifier,
        home_path="/Users/other",
        dotfiles_dir_path="other_dotfiles"
    )
    manager.db.metadata.devices[new_identifier] = other_device
    alias="other_dotfile"
    other_dotfile = DotFile(
        data=DotFileModel(
            alias=alias,
            main=f"other_dotfiles/{alias}",
            deploy={
                new_identifier: DeployedDotFile(
                    deploy_path=f"/Users/other/{alias}",
                    backups=[]
                )
            }
        ), 
        identifier=new_identifier
    )
    manager.db.data.append(other_dotfile)
    manager.db.save_all()
    
    # WHEN loading all dotfiles
    new_manager = ManageDotfiles()
    
    # THEN the dotfile should be translated to current device
    translated = new_manager.db.select_by_alias(alias)
    assert translated is not None
    assert translated.identifier == config.identifier
    assert config.identifier in translated.data.deploy.keys()
    assert translated.data.deploy[config.identifier].deploy_path.startswith(config.home)
    assert translated.data.main.startswith(config.dotfiles_dir)
    assert len(translated.data.deploy[config.identifier].backups) == 0

# ----------------------------- Variant Model Tests ----------------------------- #

@pytest.mark.run(order=16)
def test_model_new_fields_default_none(setup_test_environment):
    """Test that new fields default to None for backward compatibility."""
    model = DotFileModel(
        alias="test_compat",
        main="dotfiles/test_compat",
        deploy={}
    )
    assert model.only_devices is None
    assert model.variants is None


@pytest.mark.run(order=17)
def test_model_new_fields_roundtrip(setup_test_environment):
    """Test that only_devices and variants survive JSON serialization."""
    model = DotFileModel(
        alias="test_variant",
        main="dotfiles/test_variant",
        deploy={},
        only_devices=["TinyButMighty.ezalos"],
        variants={"TinyButMighty.ezalos": "dotfiles/test_variant.TinyButMighty"}
    )
    json_str = model.model_dump_json()
    loaded = DotFileModel.model_validate_json(json_str)
    assert loaded.only_devices == ["TinyButMighty.ezalos"]
    assert loaded.variants == {"TinyButMighty.ezalos": "dotfiles/test_variant.TinyButMighty"}


@pytest.mark.run(order=18)
def test_metadata_version_field(setup_test_environment):
    """Test that MetaDataDotFiles has version field defaulting to 1."""
    meta = MetaDataDotFiles()
    assert meta.version == 1
    json_str = meta.model_dump_json()
    loaded = MetaDataDotFiles.model_validate_json(json_str)
    assert loaded.version == 1

# ------------------------------ Migration Tests ------------------------------ #

@pytest.mark.run(order=19)
def test_migration_from_meta3(setup_test_environment):
    """Test that meta_3.json is auto-migrated to dotfiles.json with version 1."""
    import json

    # GIVEN a meta_3.json file exists and dotfiles.json does not
    meta3_path = Path(config.dotfiles_dir) / "meta_3.json"
    dotfiles_json_path = Path(config.dotfiles_dir) / "dotfiles.json"

    # Remove dotfiles.json if it exists from previous test runs
    if dotfiles_json_path.exists():
        dotfiles_json_path.unlink()

    # Write a minimal meta_3.json (old format, no version field)
    old_data = {
        "dotfiles": {
            "migration_test": {
                "alias": "migration_test",
                "main": "test_dotfiles/migration_test",
                "deploy": {}
            }
        },
        "devices": {}
    }
    meta3_path.write_text(json.dumps(old_data))

    # WHEN loading the database
    manager = ManageDotfiles()

    # THEN dotfiles.json should exist with version=1
    assert dotfiles_json_path.exists()
    with open(dotfiles_json_path) as f:
        loaded = json.loads(f.read())
    assert loaded["version"] == 1
    assert "migration_test" in loaded["dotfiles"]

    # Clean up: remove the meta_3.json we created, restore dotfiles.json as primary
    if meta3_path.exists():
        meta3_path.unlink()

# -------------------------- Only Devices Tests -------------------------- #

@pytest.mark.run(order=20)
def test_only_devices_skip(setup_test_environment):
    """Dotfile with only_devices excluding current device is skipped."""
    import json

    # GIVEN a dotfile restricted to a different device
    manager = ManageDotfiles()
    manager.db.metadata.dotfiles["restricted_file"] = DotFileModel(
        alias="restricted_file",
        main="test_dotfiles/restricted_file",
        deploy={
            "other_device.user": DeployedDotFile(
                deploy_path="/home/other/restricted_file",
                backups=[]
            )
        },
        only_devices=["other_device.user"]
    )
    manager.db.metadata.devices["other_device.user"] = DevicesData(
        identifier="other_device.user",
        home_path="/home/other",
        dotfiles_dir_path="test_dotfiles"
    )
    manager.db.save_all()

    # WHEN loading all dotfiles on current device
    new_manager = ManageDotfiles()

    # THEN the restricted dotfile should not appear
    aliases = [d.data.alias for d in new_manager.db.data]
    assert "restricted_file" not in aliases

    # Clean up
    del new_manager.db.metadata.dotfiles["restricted_file"]
    new_manager.db.save_all()


@pytest.mark.run(order=21)
def test_only_devices_deploy(setup_test_environment):
    """Dotfile with only_devices including current device deploys normally."""
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_dotfile_restricted")
    dotfile_path.write_text("restricted content")

    # GIVEN a dotfile restricted to include the current device
    manager = ManageDotfiles()
    manager.db.metadata.dotfiles["restricted_current"] = DotFileModel(
        alias="restricted_current",
        main="test_dotfiles/restricted_current",
        deploy={
            config.identifier: DeployedDotFile(
                deploy_path=str(dotfile_path),
                backups=[]
            )
        },
        only_devices=[config.identifier]
    )
    # Create the main file so deploy can symlink to it
    main_path = Path(config.project_path) / "test_dotfiles" / "restricted_current"
    main_path.write_text("restricted main content")
    manager.db.save_all()

    # WHEN loading all dotfiles
    new_manager = ManageDotfiles()

    # THEN the dotfile should appear
    aliases = [d.data.alias for d in new_manager.db.data]
    assert "restricted_current" in aliases

    # Clean up
    del new_manager.db.metadata.dotfiles["restricted_current"]
    new_manager.db.save_all()
    if main_path.exists():
        main_path.unlink()
    if dotfile_path.is_symlink():
        os.unlink(str(dotfile_path))
    elif dotfile_path.exists():
        dotfile_path.unlink()

# ----------------------------- Variant Deploy Tests ----------------------------- #

@pytest.mark.run(order=22)
def test_variant_deploy(setup_test_environment):
    """Variant for current device is used as symlink target instead of main."""
    # GIVEN a dotfile with a variant for the current device
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_variant_file")
    dotfile_path.write_text("will be replaced by symlink")

    main_path = Path(config.project_path) / "test_dotfiles" / "variant_test"
    main_path.write_text("default content")

    variant_path = Path(config.project_path) / "test_dotfiles" / "variant_test.MyDevice"
    variant_path.write_text("variant content")

    model = DotFileModel(
        alias="variant_test",
        main="test_dotfiles/variant_test",
        deploy={
            config.identifier: DeployedDotFile(
                deploy_path=str(dotfile_path),
                backups=[]
            )
        },
        variants={config.identifier: "test_dotfiles/variant_test.MyDevice"}
    )
    dotfile = DotFile(model, config.identifier)

    # WHEN deploying
    remove_file_if_exists(dotfile_path)
    dotfile.deploy()

    # THEN the symlink should point to the variant, not main
    assert dotfile_path.is_symlink()
    target = os.readlink(str(dotfile_path))
    assert target.endswith("variant_test.MyDevice")
    assert dotfile_path.read_text() == "variant content"

    # Clean up
    remove_file_if_exists(dotfile_path)
    remove_file_if_exists(main_path)
    remove_file_if_exists(variant_path)


@pytest.mark.run(order=23)
def test_variant_fallback(setup_test_environment):
    """When variant exists for another device, current device gets main."""
    # GIVEN a dotfile with a variant for a DIFFERENT device
    dotfile_path = Path(f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_variant_fallback")
    dotfile_path.write_text("will be replaced by symlink")

    main_path = Path(config.project_path) / "test_dotfiles" / "variant_fallback"
    main_path.write_text("default content")

    variant_path = Path(config.project_path) / "test_dotfiles" / "variant_fallback.OtherDevice"
    variant_path.write_text("other device content")

    model = DotFileModel(
        alias="variant_fallback",
        main="test_dotfiles/variant_fallback",
        deploy={
            config.identifier: DeployedDotFile(
                deploy_path=str(dotfile_path),
                backups=[]
            )
        },
        variants={"OtherDevice.user": "test_dotfiles/variant_fallback.OtherDevice"}
    )
    dotfile = DotFile(model, config.identifier)

    # WHEN deploying
    remove_file_if_exists(dotfile_path)
    dotfile.deploy()

    # THEN the symlink should point to main (not the variant)
    assert dotfile_path.is_symlink()
    target = os.readlink(str(dotfile_path))
    assert target.endswith("variant_fallback")
    assert not target.endswith("variant_fallback.OtherDevice")
    assert dotfile_path.read_text() == "default content"

    # Clean up
    remove_file_if_exists(dotfile_path)
    remove_file_if_exists(main_path)
    remove_file_if_exists(variant_path)


@pytest.mark.run(order=24)
def test_translate_preserves_only_devices_and_variants(setup_test_environment):
    """Test that translate_to_device preserves only_devices and variants."""
    model = DotFileModel(
        alias="translate_test",
        main="test_dotfiles/translate_test",
        deploy={
            config.identifier: DeployedDotFile(
                deploy_path=f"{config.home}/.translate_test",
                backups=[]
            )
        },
        only_devices=[config.identifier, "target_device"],
        variants={config.identifier: "test_dotfiles/translate_test.current"}
    )
    dotfile = DotFile(model, config.identifier)

    target_device = DevicesData(
        identifier="target_device",
        home_path="/home/target",
        dotfiles_dir_path="test_dotfiles_target"
    )

    translated = dotfile.translate_to_device(config.device_data, target_device)
    assert translated.data.only_devices == [config.identifier, "target_device"]
    assert translated.data.variants == {config.identifier: "test_dotfiles/translate_test.current"}
