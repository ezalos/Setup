# Register an Existing-In-Place Dotfile

## Problem

`python -m src_dotfiles add <path>` assumes `<path>` is the **deploy** location — i.e. somewhere outside `~/Setup/dotfiles/` where the file currently sits in the user's environment. It then:

1. Backs up `<path>`
2. Copies it into `dotfiles/<alias>`
3. Replaces `<path>` with a symlink → `dotfiles/<alias>`

This is wrong when the file was **authored directly inside `~/Setup/dotfiles/`** (the common case for newly created Claude skills, hook scripts, and other Setup-internal artifacts). In that scenario:

- The source is already at `~/Setup/dotfiles/<alias>` — no copy needed.
- The deploy_path is elsewhere (e.g. `~/.claude/skills/<name>`) and does not yet exist.
- `add` with `<path>=~/Setup/dotfiles/<alias>` would set `deploy_path=~/Setup/dotfiles/<alias>` (self-referential) and attempt to backup/copy a file onto itself.

The session of 2026-05-17 hit this gap registering `claude_skill_send_email`. The hand-edit-then-`deploy` workaround works but violates the `feedback_dotfiles_registry_cli_only` rule and bypasses the model invariants.

## Design

Add a third top-level subcommand to `ManageDotfiles` in `src_dotfiles/__main__.py`:

```python
def register(
    self,
    alias: str,
    deploy_path: str,
    main: Optional[str] = None,
    only_device: Optional[str] = None,
    force: bool = False,
) -> Optional[str]:
    """Register an existing-in-place dotfile and deploy it.

    Use when the source already lives at `~/Setup/<main>` (e.g. a newly
    authored SKILL.md inside `dotfiles/claude_skill_*/`) and only the
    registry entry + deploy symlink need to be created.

    Args:
        alias: Registry alias (must not collide unless force=True).
        deploy_path: Absolute path where the symlink should land
            on the current device.
        main: Path inside ~/Setup/ to the source. Default:
            `dotfiles/<alias>` (matches the convention used everywhere
            else in the registry).
        only_device: If set, restrict deploy to this device identifier.
            For skill-style dotfiles, pass the current device.
        force: Allow overwriting an existing entry with the same alias.

    Returns:
        The alias on success, None on collision (when force=False) or
        missing source.
    """
```

### Validation order

1. Resolve `main` (default `dotfiles/<alias>`).
2. Verify `~/Setup/<main>` exists. If not → log error, return None.
3. Verify `deploy_path` is absolute and rooted under a known device home (use `_infer_device_data` logic, or `config.home`). Warn otherwise; still proceed.
4. Check `alias in self.db.metadata.dotfiles`:
   - Yes + not force → log warning, return None.
   - Yes + force → load existing model, add/replace this device's deploy entry.
   - No → build a fresh `DotFileModel(alias, main, deploy={current: ...}, only_devices=[current] if only_device else None)`.
5. Skip `backup` (no original to back up) and `copy_as_main` (source already in place).
6. Call `DotFile(model, current).deploy()` to write the symlink.
7. Persist with `self.db.save_all()`.

### Comparison with `add` and `extend_to`

| Use case | Subcommand |
|---|---|
| File currently at `~/.tmux.conf`, move into dotfiles | `add ~/.tmux.conf` |
| Already tracked, add a new device deploy_path | `extend_to <alias> <device> --deploy-path=...` |
| Source already in `~/Setup/dotfiles/<alias>`, need first-device deploy | `register <alias> <deploy_path>` ← **new** |

### Edge cases

- **`deploy_path` already exists as a real file**: the underlying `DotFile.deploy()` removes it before symlinking. This is destructive — consider requiring `--force` if `deploy_path` exists and is not already a symlink to the same `main`. (Match `add`'s current behavior, which silently deletes via `os.remove` / `shutil.rmtree`.)
- **`main` is a directory (e.g. a multi-file skill)**: supported — `os.symlink` handles directories the same as files. The existing claude_skill_* entries are directories.
- **`only_device` is current_device**: the typical case for skill-style dotfiles. Set `only_devices=[current_device]` so the file isn't auto-deployed elsewhere.

## Call site changes

Update `~/Setup/dotfiles/claude_skill_add_dotfile/SKILL.md` Phase 2 routing:
already done — the routing now says "if target_path inside `~/Setup/dotfiles/`, route to `register`". Once the subcommand exists, remove the "if that subcommand does not yet exist, build it" caveat.

## Testing

Smoke test before shipping:

```bash
# Create a throwaway skill source
mkdir -p ~/Setup/dotfiles/claude_skill_test_register
echo "test" > ~/Setup/dotfiles/claude_skill_test_register/SKILL.md

# Register it
cd ~/Setup && python -m src_dotfiles register \
    claude_skill_test_register \
    /tmp/test_register_deploy \
    --only-device=TheBeast.ezalos

# Verify
test -L /tmp/test_register_deploy
readlink /tmp/test_register_deploy
# → /home/ezalos/Setup/dotfiles/claude_skill_test_register

# Cleanup (manual delete of registry entry + rm of symlink + source)
```

Add a real test in `tests/` once the smoke test passes.

## Open question

Should `register` and `add` share validation/persistence helpers? Currently `add` does a lot inline. Extracting `_create_or_update_model(alias, main, deploy_path, only_device, force) -> DotFileModel` would let both paths share collision logic.
