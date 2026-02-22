# Per-Device Variants for Dotfiles Deployer

## Problem

The dotfiles deployer treats every dotfile as global — one `main` file deployed to all devices. This creates two gaps:

1. **Device-specific content**: Claude Code settings need an unsafe version on the Pi but safe version everywhere else. The current workaround (`unsafe_claude_settings` overwriting `claude_settings` in the dotfiles dir) is fragile and pollutes the source of truth.
2. **Device-only files**: nginx configs only belong on the Pi. Currently they get auto-translated and deployed everywhere.

## Design

### Model Changes

Two new optional fields on `DotFileModel`:

```python
class DotFileModel(BaseModel):
    alias: Alias
    main: str
    deploy: Dict[Identifier, DeployedDotFile] = Field(default_factory=dict)
    only_devices: Optional[List[Identifier]] = None
    variants: Optional[Dict[Identifier, str]] = None
```

- **`only_devices`**: When `None` (default), deploy to all devices. When set, deploy only to listed devices. Backward compatible.
- **`variants`**: Maps device identifier to a variant file path. At deploy time, the variant replaces `main` as the symlink target for that device.

### Variant File Convention

Variant files live alongside main with a device suffix:
```
dotfiles/claude_settings                      # default (safe)
dotfiles/claude_settings.TinyButMighty        # Pi variant (unsafe)
```

### Deploy Logic

```
for each dotfile:
    if only_devices is set and current_device not in list:
        skip entirely (no translate, no deploy, no backup)
    backup current file at deploy_path
    target = variants[current_device] if exists, else main
    create symlink: deploy_path -> target
```

Changes touch:
- `database.py` `load_all()`: skip dotfiles excluded by `only_devices`
- `DotFile.deploy()`: resolve variant before creating symlink
- `__main__.py`: add `--only-device` flag to `add` command

### Metadata File Migration

Rename `meta_3.json` to `dotfiles.json` with a `version` field for future migrations:

```json
{
    "version": 1,
    "dotfiles": { ... },
    "devices": { ... }
}
```

Root model change:
```python
class MetaDataDotFiles(BaseModel):
    version: int = 1
    dotfiles: Dict[Alias, DotFileModel] = Field(default_factory=dict)
    devices: Dict[Identifier, DevicesData] = Field(default_factory=dict)
```

**Migration logic** (in `database.py`):
1. If `dotfiles.json` exists, load it. Check version, apply any needed migrations.
2. If not, look for `meta_3.json`. Load it, set version=1, save as `dotfiles.json`.
3. Old files (`meta.json`, `meta_2.json`, `meta_3.json`) are left in place, ignored.

**Data migration for existing entries**:
- Remove `unsafe_claude_settings` entry
- Add to `claude_settings`: `"variants": {"TinyButMighty.ezalos": "dotfiles/claude_settings.TinyButMighty"}`
- Rename file `dotfiles/unsafe_claude_settings` to `dotfiles/claude_settings.TinyButMighty`
- Add to nginx entries: `"only_devices": ["TinyButMighty.ezalos"]`
- Redo the nginx entries properly via `uv run python -m src_dotfiles add` (the manual meta_3.json edit was wrong)

### Tests

New tests:
1. `test_only_devices_skip` — dotfile with `only_devices=["other"]` skipped on current device
2. `test_only_devices_deploy` — dotfile with `only_devices=[current]` deploys normally
3. `test_variant_deploy` — variant for current device used as symlink target instead of main
4. `test_variant_fallback` — variant for other device, current device gets main
5. `test_migration_from_meta3` — meta_3.json auto-migrated to dotfiles.json version 1
6. `test_version_field` — loaded metadata has correct version number

Existing tests pass unchanged (new fields default to `None`).

### What Gets Cleaned Up

- The `unsafe_claude_settings` hack is eliminated
- `claude_settings` becomes a single dotfile with a variant
- nginx configs get `only_devices` instead of relying on deploy-dict pruning
- Metadata gets a version number for future-proof migrations
