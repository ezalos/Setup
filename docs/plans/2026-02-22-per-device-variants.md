# Per-Device Variants Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `only_devices` and `variants` fields to the dotfiles deployer so individual dotfiles can be restricted to specific devices or have per-device content, and migrate metadata from `meta_3.json` to a versioned `dotfiles.json`.

**Architecture:** Two new optional fields on `DotFileModel` (`only_devices`, `variants`) control deployment filtering and per-device symlink targets. A `version` field on `MetaDataDotFiles` enables future migrations. The database layer auto-migrates from `meta_3.json` to `dotfiles.json` on first load. All changes are backward-compatible — existing data loads with `None` defaults.

**Tech Stack:** Python 3.10+, Pydantic v2, pytest with pytest-ordering, Fire CLI. Run with `uv run`.

---

### Task 1: Add New Fields to Pydantic Models

**Files:**
- Modify: `src_dotfiles/models.py:31-45` (DotFileModel)
- Modify: `src_dotfiles/models.py:60-72` (MetaDataDotFiles)
- Test: `tests/test_dotfiles.py`

**Step 1: Write the failing test**

Add at the bottom of `tests/test_dotfiles.py`:

```python
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
```

Also add `MetaDataDotFiles` to the import on line 10:

```python
from src_dotfiles.models import DevicesData, DotFileModel, DeployedDotFile, MetaDataDotFiles
```

**Step 2: Run tests to verify they fail**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py::test_model_new_fields_default_none tests/test_dotfiles.py::test_model_new_fields_roundtrip tests/test_dotfiles.py::test_metadata_version_field -v`
Expected: FAIL — `DotFileModel` has no field `only_devices` / `variants`, `MetaDataDotFiles` has no field `version`

**Step 3: Implement the model changes**

In `src_dotfiles/models.py`, modify `DotFileModel` (line 31-45) to add two fields after `deploy`:

```python
class DotFileModel(BaseModel):
    """
    Represents a dotfile and its deployment configuration.

    A dotfile is a configuration file that can be tracked and synchronized across systems.
    This model includes the alias, the main version in the dotfiles directory, and deployment details.

    Attributes:
        alias (str): The name used to identify the dotfile (usually the filename or a unique alias).
        main (str): The path to the main version of the dotfile in the dotfiles directory.
        deploy (Dict[Identifier, DeployedDotFile]): Dictionary of deployment information for this dotfile on different systems.
        only_devices (Optional[List[Identifier]]): When set, deploy only to these devices. None means deploy everywhere.
        variants (Optional[Dict[Identifier, str]]): Maps device identifier to variant file path (replaces main on that device).
    """
    alias: Alias
    main: str
    deploy: Dict[Identifier, DeployedDotFile] = Field(default_factory=dict)
    only_devices: Optional[List[Identifier]] = None
    variants: Optional[Dict[Identifier, str]] = None
```

In `src_dotfiles/models.py`, modify `MetaDataDotFiles` (line 60-72) to add `version`:

```python
class MetaDataDotFiles(BaseModel):
    """
    Root model representing the metadata for all dotfiles and devices.

    This model contains all tracked dotfiles and the configuration for each device
    where dotfiles can be deployed.

    Attributes:
        version (int): Schema version number for migration support.
        dotfiles (Dict[str, DotFileModel]): Dictionary mapping dotfile aliases to their models.
        devices (Dict[str, DevicesData]): Mapping of system identifiers to their device configuration.
    """
    version: int = 1
    dotfiles: Dict[Alias, DotFileModel] = Field(default_factory=dict)
    devices: Dict[Identifier, DevicesData] = Field(default_factory=dict)
```

**Step 4: Run tests to verify they pass**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py -v`
Expected: ALL PASS (16 existing + 3 new)

**Step 5: Commit**

```bash
cd /home/ezalos/Setup && git add src_dotfiles/models.py tests/test_dotfiles.py
git commit -m "feat: add only_devices, variants, and version fields to dotfile models"
```

---

### Task 2: Migrate Metadata File from meta_3.json to dotfiles.json

**Files:**
- Modify: `src_dotfiles/config.py:53-77` (set_config)
- Modify: `src_dotfiles/database.py:29-59` (Dependencies.__init__)
- Test: `tests/test_dotfiles.py`

**Step 1: Write the failing test**

Add at the bottom of `tests/test_dotfiles.py`:

```python
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
```

**Step 2: Run test to verify it fails**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py::test_migration_from_meta3 -v`
Expected: FAIL — config still points to `meta_3.json`, no migration logic

**Step 3: Update config.py to use dotfiles.json**

In `src_dotfiles/config.py`, in the `set_config()` function, change line 60:

```python
# Before:
config.depedencies_path = Path(config.dotfiles_dir).joinpath('meta_3.json').as_posix()

# After:
config.depedencies_path = Path(config.dotfiles_dir).joinpath('dotfiles.json').as_posix()
config.legacy_meta3_path = Path(config.dotfiles_dir).joinpath('meta_3.json').as_posix()
```

**Step 4: Add migration logic to database.py**

In `src_dotfiles/database.py`, modify `Dependencies.__init__()` (lines 29-59). Replace the db_path loading section with migration-aware logic:

```python
def __init__(self):
    """Initialize the Dependencies manager.

    Loads metadata from file if it exists, otherwise creates empty metadata.
    Migrates from meta_3.json to dotfiles.json if needed.
    Then loads all dotfiles and translates them to current device if needed.
    """
    self.test: bool = False
    self.data: List[DotFile] = []  # Initialize data as empty list first
    logger.debug(f"{config.depedencies_path = }")
    logger.debug(f"{config.dotfiles_dir = }")
    self.path: str = config.depedencies_path
    self.path_test: str = config.dotfiles_dir + "test_" + "meta.json"
    self.db_path = self.get_db_path()
    logger.debug(f"{self.db_path = }")

    if self.db_path.exists():
        logger.debug(f"Loading metadata from {self.db_path}")
        with open(self.db_path, "r") as f:
            self.metadata = MetaDataDotFiles.model_validate_json(f.read())
    elif self._legacy_db_path().exists():
        logger.info(f"Migrating from {self._legacy_db_path()} to {self.db_path}")
        with open(self._legacy_db_path(), "r") as f:
            self.metadata = MetaDataDotFiles.model_validate_json(f.read())
        # Ensure version is set (old files won't have it, Pydantic defaults to 1)
        self.save_all()
    else:
        logger.debug(f"Creating new metadata")
        self.metadata = MetaDataDotFiles(
            dotfiles={},
            devices={
                config.identifier: config.device_data
            }
        )
        self.save_all()

    # Load and translate dotfiles after metadata is initialized
    self.data = self.load_all()

def _legacy_db_path(self) -> Path:
    """Get the path to the legacy meta_3.json file."""
    return Path(config.project_path).joinpath(config.legacy_meta3_path)
```

**Step 5: Run tests to verify they pass**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py -v`
Expected: ALL PASS. The test suite already uses `set_config(dotfiles_dir="test_dotfiles")` so test isolation is preserved. Existing tests still work because `Dependencies.__init__` now creates `dotfiles.json` instead of `meta_3.json`, and the test data directory is fresh each run.

**Step 6: Commit**

```bash
cd /home/ezalos/Setup && git add src_dotfiles/config.py src_dotfiles/database.py tests/test_dotfiles.py
git commit -m "feat: migrate metadata from meta_3.json to dotfiles.json with version field"
```

---

### Task 3: Implement only_devices Filtering in load_all()

**Files:**
- Modify: `src_dotfiles/database.py:131-157` (Dependencies.load_all)
- Test: `tests/test_dotfiles.py`

**Step 1: Write the failing tests**

Add at the bottom of `tests/test_dotfiles.py`:

```python
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
    remove_file_if_exists(main_path)
    remove_file_if_exists(dotfile_path)
```

**Step 2: Run tests to verify they fail**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py::test_only_devices_skip tests/test_dotfiles.py::test_only_devices_deploy -v`
Expected: FAIL — `test_only_devices_skip` will fail because `load_all()` doesn't check `only_devices` (it currently tries to translate and include the dotfile)

**Step 3: Implement only_devices filtering in load_all()**

In `src_dotfiles/database.py`, modify `load_all()` method. Add a check at the top of the loop, right after `for alias, model in self.metadata.dotfiles.items():`:

```python
def load_all(self) -> List[DotFile]:
    """Converts the metadata into usable DotFile objects.

    If a dotfile has only_devices set and current device is not in the list, skip it.
    If a dotfile is from a different device, translates its paths to current device.

    Returns:
        List[DotFile]: List of DotFile objects
    """
    dotfiles = []
    for alias, model in self.metadata.dotfiles.items():
        # Skip dotfiles restricted to other devices
        if model.only_devices is not None and config.identifier not in model.only_devices:
            logger.debug(f"Skipping {alias}: only_devices={model.only_devices}, current={config.identifier}")
            continue

        if config.identifier not in model.deploy.keys():
            # Get device data for translation
            known_devices_in_model = [i for i in model.deploy.keys() if i in self.metadata.devices.keys()]

            if len(known_devices_in_model) == 0:
                logger.warning(f"All the devices from model {model.deploy.keys() = } not found in metadata, skipping {model.alias = }")
                continue
            else:
                model_identifier = known_devices_in_model[0]

            original_device = self.metadata.devices[model_identifier]
            translated = DotFile(model).translate_to_device(original_device, config.device_data)
            dotfiles.append(translated)
        else:
            dotfiles.append(DotFile(model, config.identifier))
    self.update_dotfiles(dotfiles)
    return dotfiles
```

**Step 4: Run tests to verify they pass**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py -v`
Expected: ALL PASS

**Step 5: Commit**

```bash
cd /home/ezalos/Setup && git add src_dotfiles/database.py tests/test_dotfiles.py
git commit -m "feat: add only_devices filtering to skip device-specific dotfiles"
```

---

### Task 4: Implement Variant Resolution in deploy()

**Files:**
- Modify: `src_dotfiles/DotFile.py:61-86` (DotFile.deploy)
- Test: `tests/test_dotfiles.py`

**Step 1: Write the failing tests**

Add at the bottom of `tests/test_dotfiles.py`:

```python
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
```

**Step 2: Run tests to verify they fail**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py::test_variant_deploy tests/test_dotfiles.py::test_variant_fallback -v`
Expected: `test_variant_deploy` FAILS — symlink points to `variant_test` (main) instead of `variant_test.MyDevice`. `test_variant_fallback` may PASS since it falls back to main anyway.

**Step 3: Implement variant resolution in deploy()**

In `src_dotfiles/DotFile.py`, modify the `deploy()` method (lines 61-86). Replace the line that resolves `main` (line 84) with variant-aware logic:

```python
def deploy(self) -> None:
    """Deploy the dotfile in the system.

    Creates a symlink from the system path to the main version,
    or to a device variant if one exists for this device.
    Will delete any existing file at the target path.
    """
    dirs = os.path.dirname(self.data.deploy[self.identifier].deploy_path)
    logger.debug(f'Extracting dir part of src: {dirs}')

    try:
        if os.path.exists(self.data.deploy[self.identifier].deploy_path):
            logger.debug(f'Deleting {self.data.deploy[self.identifier].deploy_path}')
            if os.path.isdir(self.data.deploy[self.identifier].deploy_path) and not os.path.islink(self.data.deploy[self.identifier].deploy_path):
                shutil.rmtree(self.data.deploy[self.identifier].deploy_path)
            else:
                os.remove(self.data.deploy[self.identifier].deploy_path)
    except Exception as e:
        logger.debug(f"Could not remove {self.data.deploy[self.identifier].deploy_path}: {str(e)}")

    if not os.path.exists(dirs):
        logger.info(f'{dirs} does not exist: creating it')
        os.makedirs(dirs)

    # Resolve variant: use device-specific file if one exists, otherwise main
    source = self.data.main
    if self.data.variants and self.identifier in self.data.variants:
        source = self.data.variants[self.identifier]
        logger.info(f"Using variant for {self.identifier}: {source}")

    target = Path(config.project_path).joinpath(source).as_posix()
    logger.info(f"Symlink created {self.data.deploy[self.identifier].deploy_path} -> {target}")
    os.symlink(target, self.data.deploy[self.identifier].deploy_path)
```

**Step 4: Run tests to verify they pass**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py -v`
Expected: ALL PASS

**Step 5: Commit**

```bash
cd /home/ezalos/Setup && git add src_dotfiles/DotFile.py tests/test_dotfiles.py
git commit -m "feat: resolve device variants in deploy, falling back to main"
```

---

### Task 5: Preserve only_devices and variants in translate_to_device()

**Files:**
- Modify: `src_dotfiles/DotFile.py:134-180` (DotFile.translate_to_device)

**Step 1: Write the failing test**

Add at the bottom of `tests/test_dotfiles.py`:

```python
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
```

**Step 2: Run test to verify it fails**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py::test_translate_preserves_only_devices_and_variants -v`
Expected: FAIL — `translate_to_device` constructs a new `DotFileModel` without `only_devices` or `variants`

**Step 3: Implement the fix**

In `src_dotfiles/DotFile.py`, in `translate_to_device()`, modify the `DotFileModel` constructor call (around line 169) to pass through the new fields:

```python
        # Create new model with translated paths
        new_model = DotFileModel(
            alias=self.data.alias,
            main=new_main,
            deploy={
                target_device.identifier: DeployedDotFile(
                    deploy_path=new_path,
                    backups=[]
                )
            },
            only_devices=self.data.only_devices,
            variants=self.data.variants,
        )
```

**Step 4: Run tests to verify they pass**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py -v`
Expected: ALL PASS

**Step 5: Commit**

```bash
cd /home/ezalos/Setup && git add src_dotfiles/DotFile.py tests/test_dotfiles.py
git commit -m "feat: preserve only_devices and variants through device translation"
```

---

### Task 6: Add --only-device Flag to CLI add Command

**Files:**
- Modify: `src_dotfiles/__main__.py:25-68` (ManageDotfiles.add)
- Modify: `src_dotfiles/database.py:89-129` (Dependencies.create_dotfile)

**Step 1: Write the failing test**

Add at the bottom of `tests/test_dotfiles.py`:

```python
@pytest.mark.run(order=25)
def test_add_with_only_device(setup_test_environment):
    """Test that --only-device flag sets only_devices on the dotfile."""
    dotfile_path = f"{setup_test_environment['TEST_DATA_TMP'].as_posix()}/test_only_device_add"
    Path(dotfile_path).write_text("only device content")

    # Create the main file first (simulating it already exists)
    main_path = Path(config.project_path) / "test_dotfiles" / "only_device_add"
    main_path.write_text("only device content")

    manager = ManageDotfiles()
    alias = manager.add(path=dotfile_path, alias="only_device_add", only_device=config.identifier)
    assert alias == "only_device_add"

    # Verify only_devices is set
    new_manager = ManageDotfiles()
    dotfile = new_manager.db.select_by_alias("only_device_add")
    assert dotfile is not None
    assert dotfile.data.only_devices == [config.identifier]

    # Clean up
    remove_file_if_exists(Path(dotfile_path))
    remove_file_if_exists(main_path)
```

**Step 2: Run test to verify it fails**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py::test_add_with_only_device -v`
Expected: FAIL — `add()` doesn't accept `only_device` parameter

**Step 3: Implement the CLI flag**

In `src_dotfiles/__main__.py`, add `only_device` parameter to `add()`:

```python
def add(self, path: str, alias: Optional[str] = None, force: bool = False, only_device: Optional[str] = None) -> Optional[str]:
    """Add a new dotfile to be managed by the system.

    Args:
        path (str): Path to the dotfile to add
        alias (Optional[str]): Custom alias for the dotfile. If not provided, will be generated from filename.
        force (bool): Whether to force add if alias already exists.
        only_device (Optional[str]): Restrict this dotfile to a specific device identifier.

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
```

In `src_dotfiles/database.py`, add `only_device` parameter to `create_dotfile()`:

```python
def create_dotfile(self, path: str, alias: Optional[str] = None, only_device: Optional[str] = None) -> DotFile:
    """Create a new DotFile instance with appropriate model

    Args:
        path (str): Path where the dotfile should exist in the system
        alias (Optional[str]): Custom alias for the dotfile. Default: filename from path
        only_device (Optional[str]): Restrict this dotfile to a specific device identifier.

    Returns:
        DotFile: New DotFile instance
    """
    if alias is None:
        alias = Path(path).name

    identifier=config.identifier
    main=Path(config.dotfiles_dir).joinpath(alias).as_posix()


    if alias in self.metadata.dotfiles.keys():
        dot_file_model = self.metadata.dotfiles[alias]
    else:
        dot_file_model = DotFileModel(
            alias=alias,
            main=main,
            deploy={
                identifier: DeployedDotFile(
                    deploy_path=path,
                    backups=[]
                )
            },
            only_devices=[only_device] if only_device else None,
        )

    if identifier in dot_file_model.deploy.keys():
        old_backups = dot_file_model.deploy[identifier].backups
    else:
        old_backups = []

    dot_file_model.deploy[identifier] = DeployedDotFile(
        deploy_path=path,
        backups=old_backups
    )
    return DotFile(dot_file_model, identifier)
```

**Step 4: Run tests to verify they pass**

Run: `cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py -v`
Expected: ALL PASS

**Step 5: Commit**

```bash
cd /home/ezalos/Setup && git add src_dotfiles/__main__.py src_dotfiles/database.py tests/test_dotfiles.py
git commit -m "feat: add --only-device flag to CLI add command"
```

---

### Task 7: Run Full Production Migration

This task migrates the real `meta_3.json` to `dotfiles.json` and cleans up the `unsafe_claude_settings` hack. **No tests** — this is a data migration on the live metadata.

**Context:**
- `dotfiles/claude_settings` is currently a broken symlink → `dotfiles/unsafe_claude_settings` (file deleted)
- `meta_3.json` has an `unsafe_claude_settings` entry that deploys to `dotfiles/claude_settings` (overwriting main)
- nginx entries (`nginx.conf`, `nginx_port_forward.conf`) were manually added and should get `only_devices`

**Step 1: Trigger automatic migration**

Run the deployer once — it will detect `meta_3.json`, migrate to `dotfiles.json`, and save with `version: 1`:

```bash
cd /home/ezalos/Setup && uv run python -c "from src_dotfiles.database import Dependencies; Dependencies()"
```

Verify: `ls -la dotfiles/dotfiles.json` should exist with version=1.

**Step 2: Fix the broken claude_settings symlink**

The broken symlink `dotfiles/claude_settings → dotfiles/unsafe_claude_settings` needs to be replaced with the actual safe settings file. First check what TheBeast has deployed:

```bash
# Remove the broken symlink
rm dotfiles/claude_settings

# Get the safe version from TheBeast's backup or from the currently deployed file
# The safe version should be at the backup path from TheBeast
# If no backup is available, get it from the deployed location on another machine
# For now, create a placeholder that will be overwritten on next deploy from a safe machine
```

> **Note to implementer:** The safe `claude_settings` file should be copied from a machine that has the safe version (e.g., TheBeast). If a backup exists at `dotfiles/old/claude_settings_TheBeast.ezalos_*`, use that. Otherwise, manually copy from `~/.claude/settings.json` on a safe machine.

**Step 3: Create the TinyButMighty variant file**

Copy the current Pi's unsafe settings as the variant:

```bash
cp /home/ezalos/.claude/settings.json dotfiles/claude_settings.TinyButMighty
```

**Step 4: Edit dotfiles.json to add variant and only_devices**

```bash
cd /home/ezalos/Setup && uv run python -c "
import json
from pathlib import Path

db = Path('dotfiles/dotfiles.json')
data = json.loads(db.read_text())

# Remove unsafe_claude_settings entry
if 'unsafe_claude_settings' in data['dotfiles']:
    del data['dotfiles']['unsafe_claude_settings']
    print('Removed unsafe_claude_settings entry')

# Add variant to claude_settings
if 'claude_settings' in data['dotfiles']:
    data['dotfiles']['claude_settings']['variants'] = {
        'TinyButMighty.ezalos': 'dotfiles/claude_settings.TinyButMighty'
    }
    print('Added TinyButMighty variant to claude_settings')

# Add only_devices to nginx entries
for alias in ['nginx.conf', 'nginx_port_forward.conf']:
    if alias in data['dotfiles']:
        data['dotfiles'][alias]['only_devices'] = ['TinyButMighty.ezalos']
        print(f'Added only_devices to {alias}')

db.write_text(json.dumps(data, indent=4))
print('Saved dotfiles.json')
"
```

**Step 5: Re-register nginx entries properly via CLI**

Remove the manually-added nginx entries and re-add them with `--only-device`:

```bash
cd /home/ezalos/Setup

# The entries are already in dotfiles.json from the script above with only_devices set.
# We just need to verify they work. Run deploy to check:
uv run python -m src_dotfiles deploy nginx.conf
uv run python -m src_dotfiles deploy nginx_port_forward.conf
```

> **Note:** These will fail to symlink because the deploy paths are in `/etc/nginx/` (root-owned). That's expected — nginx configs are manually deployed with `sudo cp`. The metadata is correct for tracking purposes.

**Step 6: Verify the migration**

```bash
cd /home/ezalos/Setup && uv run python -c "
from src_dotfiles.database import Dependencies
db = Dependencies()

# Check version
print(f'Version: {db.metadata.version}')

# Check unsafe_claude_settings is gone
assert 'unsafe_claude_settings' not in db.metadata.dotfiles, 'unsafe_claude_settings still exists!'

# Check claude_settings has variant
cs = db.metadata.dotfiles.get('claude_settings')
if cs:
    print(f'claude_settings variants: {cs.variants}')
    assert cs.variants is not None

# Check nginx has only_devices
for alias in ['nginx.conf', 'nginx_port_forward.conf']:
    df = db.metadata.dotfiles.get(alias)
    if df:
        print(f'{alias} only_devices: {df.only_devices}')
        assert df.only_devices == ['TinyButMighty.ezalos']

print('Migration verified successfully!')
"
```

**Step 7: Run all tests to confirm nothing broke**

```bash
cd /home/ezalos/Setup && uv run pytest tests/test_dotfiles.py -v
```

Expected: ALL PASS

**Step 8: Commit**

```bash
cd /home/ezalos/Setup && git add dotfiles/dotfiles.json dotfiles/claude_settings.TinyButMighty dotfiles/claude_settings
git commit -m "feat: migrate to dotfiles.json, add claude_settings variant, restrict nginx to Pi"
```
