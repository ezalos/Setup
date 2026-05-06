---
name: add-dotfile
description: Use when Louis asks to track a file as a dotfile (e.g. "add ~/.tmux.conf to my dotfiles", "track this config", "manage X via dotfiles") OR to set up tracked dotfiles on the current machine (e.g. "deploy my dotfiles here", "I'm on a new machine, sync up", "deploy <alias> on this device"). Wraps the dotfiles.json registry and src_dotfiles deployer; routes by inspecting registry + filesystem state.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
---

# add-dotfile

Single entry point for the dotfile lifecycle: ADD (start tracking a file), DEPLOY-HERE (set up a tracked dotfile on this machine), or REDEPLOY (re-create a missing symlink). Routes by inspecting world state, not by user-supplied subcommand.

## Observability

This skill follows the universal observability baseline (see `docs/plans/2026-04-21-skill-storage-observability-design.md`).

**Universal baseline:**
- CRITICAL on abort.
- WARNING on user correction (Claude was about to be wrong), fallback, retry, precondition-fail.
- **INFO (systematic) on any user feedback, suggestion, or caveat during the run.** Every distinct user message that conveys preference, redirection, refinement, or commentary MUST be logged. Format: `feedback: '<paraphrase>'; phase=<where>; changed <what>` (or `no change — already on track`).
- INFO on edge-case path hit.

**Skill-specific triggers:**

| Level | Trigger | Message template |
|---|---|---|
| CRITICAL | target_path doesn't exist on ADD | `add-dotfile: target <path> does not exist` |
| CRITICAL | src_dotfiles deployer raises | `add-dotfile: deployer failed for <alias>: <reason>` |
| CRITICAL | ~/Setup not a git repo / dotfiles.json missing | `add-dotfile: setup broken: <reason>` |
| WARNING | Alias collision required user override | `add-dotfile: alias collision for <derived>; using <override>` |
| WARNING | Ambiguous state — handed back to user (ASK path) | `add-dotfile: ambiguous state for <target>; <observation>` |
| WARNING | DEPLOY-HERE prompted for deploy_path with no good default | `add-dotfile: no similar device for <alias>; user provided <path>` |
| INFO | No-op (already correctly deployed) | `add-dotfile: no-op for <alias> on <device>` |
| INFO | First-time deploy on this device (DEPLOY-HERE path) | `add-dotfile: first deploy for <alias> on <device>` |
| INFO | Re-deploy (REDEPLOY path) | `add-dotfile: redeploy for <alias> on <device>` |

Concrete invocation examples:

```
claude-log add-dotfile INFO "add-dotfile: starting; target=/home/ezalos/.tmux.conf"
claude-log add-dotfile WARNING "add-dotfile: alias collision for .config; using nvim/init.lua"
claude-log add-dotfile CRITICAL "add-dotfile: target /home/ezalos/.foorc does not exist"
```

# triggers I might have missed: <none>

## Preconditions (check first; CRITICAL + abort on failure)

1. `~/Setup/` is a git repo: `git -C ~/Setup rev-parse --is-inside-work-tree` returns `true`.
2. `~/Setup/dotfiles/dotfiles.json` exists and parses as JSON: `python -c "import json; json.load(open('/home/ezalos/Setup/dotfiles/dotfiles.json'))"`.
3. `python -m src_dotfiles --help` runs successfully from `~/Setup/`.

If any fail: log CRITICAL `add-dotfile: setup broken: <reason>` and report the failing precondition to Louis. Do not proceed.

## Phase 1 — gather inputs

From the user's request, extract:

- **target_path**: the absolute path the user named (resolve `~`, relative paths to absolute).
- **target_alias** (candidate): the basename of target_path (e.g. `~/.zshrc` → `.zshrc`, `~/.config/nvim/init.lua` → `init.lua`).

Determine the current device:

```bash
cd ~/Setup && python -c "from src_dotfiles.config import config; print(config.identifier)"
```

Capture as `current_device` (e.g. `TheBeast.ezalos`).

Read the registry:

```python
import json
registry = json.load(open('/home/ezalos/Setup/dotfiles/dotfiles.json'))
```

## Phase 2 — classify intent (route to one of ADD / DEPLOY-HERE / REDEPLOY / ASK / NO-OP)

Inspect:

- Does `target_path` exist on disk?
- Is `target_path` already a symlink? Where does it point?
- Does an entry with this alias exist in `registry["dotfiles"]`?
- If yes: does that entry have a `deploy[<current_device>]` block?
- If yes: does the entry's `main` file exist at the expected location?

Routing table:

| target exists | target is symlink | alias in registry | deploy block for current device | symlink resolves to expected main | → Path |
|---|---|---|---|---|---|
| no | — | no | — | — | **CRITICAL: target missing** |
| no | — | yes | yes | — | **REDEPLOY** (file gone, registry says it should be here) |
| yes | no | no | — | — | **ADD** |
| yes | no | yes | no | — | **DEPLOY-HERE** |
| yes | yes | yes | yes | yes | **NO-OP** (already correctly deployed) |
| yes | yes | yes | yes | no (broken symlink target) | **REDEPLOY** |
| yes | yes | yes | no | — | **ADD** (existing symlink unrelated; back up + replace) |
| any | — | yes | — | conflicting state (e.g. file path differs from `deploy_path`) | **ASK** |

State the inferred path explicitly to Louis before executing ("I'll add this as a new dotfile entry…" / "I see this is already tracked but not deployed here — I'll deploy it now").

If ASK: log WARNING `add-dotfile: ambiguous state for <target>; <observation>` and return control to Louis with the relevant context. Do not guess.

## Phase 3 — ADD path

When intent classified as ADD:

### 3a. Resolve alias (with collision check)

1. Auto-derive: `derived = basename(target_path)`.
2. Check collision: `derived in registry["dotfiles"]`?
   - If no collision → use `derived` as the alias.
   - If collision → show Louis the existing entry's `main` path. Use AskUserQuestion to ask for an override alias. Suggest a path-disambiguated form (e.g. parent directory + filename: `nvim/init.lua` instead of just `init.lua`). Log WARNING `add-dotfile: alias collision for <derived>; using <override>`.

### 3b. Move into the dotfiles directory

1. Compute main: `main_path = "dotfiles/<alias>"` relative to `~/Setup/`.
2. Copy the file: `cp -r <target_path> ~/Setup/<main_path>` (or `cp <target_path> ~/Setup/<main_path>` for files; preserve mode bits).
3. Verify: file exists at `~/Setup/<main_path>` with same contents as `target_path`.

### 3c. Add the registry entry

Edit `~/Setup/dotfiles/dotfiles.json`. Add:

```json
"<alias>": {
    "alias": "<alias>",
    "main": "dotfiles/<alias>",
    "deploy": {
        "<current_device>": {
            "deploy_path": "<absolute target_path>",
            "backups": []
        }
    },
    "only_devices": null,
    "variants": null
}
```

Verify JSON parses after the edit.

### 3d. Deploy

```bash
cd ~/Setup && python -m src_dotfiles deploy --alias=<alias>
```

The deployer handles: backup of any existing file at `target_path`, removal, symlink creation. If it raises:
- Log CRITICAL `add-dotfile: deployer failed for <alias>: <reason>`.
- The local registry edit and the file copy persist; Louis can investigate. Don't try to "rollback" — the deployer's own state machine is the authority.
- Abort.

### 3e. Verify

- `target_path` is a symlink.
- Symlink points to `~/Setup/dotfiles/<alias>`.
- `~/Setup/dotfiles/<alias>` is a real file/dir (not a symlink itself).

### 3f. Commit

```bash
cd ~/Setup
git add dotfiles/dotfiles.json dotfiles/<alias>
git commit -m "dotfiles: track <alias>"
```

Per Louis's CLAUDE.md: own repos commit directly to default branch. Don't push unless Louis asked.

If the commit fails (hooks, etc.): log WARNING `add-dotfile: commit hook failed for <alias>: <reason>` and report to Louis. Do not `--no-verify`.

Log INFO `add-dotfile: first deploy for <alias> on <current_device>`.

## Phase 4 — DEPLOY-HERE path

When intent classified as DEPLOY-HERE:

1. Show the existing entry to Louis: alias, main path, devices already deployed (paths).
2. Propose a `deploy_path` for current_device:
   - Heuristic: pick the most similar existing device's `deploy_path` (same OS prefix, same user-home pattern). For example, if there's a `Linux` device with `/home/<user>/.zshrc`, propose `/home/<current-user>/.zshrc`.
   - If no similar device: log WARNING `add-dotfile: no similar device for <alias>; user provided <path>` and use AskUserQuestion to ask Louis for the path.
3. Add the deploy block to `dotfiles.json`:

   ```json
   "<current_device>": {
       "deploy_path": "<provided>",
       "backups": []
   }
   ```

4. Deploy: `python -m src_dotfiles deploy --alias=<alias>`. Same error handling as Phase 3d.
5. Verify: symlink at `<provided>` → `~/Setup/<main>`.
6. Commit: `dotfiles: deploy <alias> on <current_device>`.
7. Log INFO `add-dotfile: first deploy for <alias> on <current_device>`.

## Phase 5 — REDEPLOY path

When intent classified as REDEPLOY (entry exists, deploy block exists, but symlink missing or broken):

1. Confirm with Louis using AskUserQuestion: "Entry for `<alias>` exists for this device but the symlink is missing/broken. Re-deploy?" Default: yes.
2. On confirm: `python -m src_dotfiles deploy --alias=<alias>`. Same error handling.
3. Verify: symlink restored.
4. **No `dotfiles.json` change. No commit.**
5. Log INFO `add-dotfile: redeploy for <alias> on <current_device>`.

## Phase 6 — NO-OP path

When intent classified as NO-OP (already correctly deployed):

1. Tell Louis: "Already deployed: `<target_path>` → `~/Setup/<main>`. Nothing to do."
2. Log INFO `add-dotfile: no-op for <alias> on <current_device>`.
3. End.

## Phase 7 — self-improvement

After completing any path (ADD / DEPLOY-HERE / REDEPLOY / NO-OP / abort), review user feedback from this run. If user input would have produced better behavior, this skill itself can be edited (see wrap-up Phase 3 "Skill self-improvement"). Defer to wrap-up to actually edit if user runs that next; otherwise leave a note in the consolidated report.

## Constraints

- **Never use `git add -A`** — stage explicit paths.
- **Never use `--no-verify`** — if a hook fails, report and stop.
- **Never delete original target_path** before the deployer succeeds — the deployer itself does the swap (file → symlink) atomically.
- **Don't pollute `dotfiles.json` on partial failure** — write registry edits AFTER the deploy succeeds, not before. (Reorder Phase 3c and 3d if needed: deploy first, then registry update — if the deployer requires the registry first, write to a temp registry, deploy, then atomic-rename. Verify behavior of `python -m src_dotfiles add` for the canonical add-flow if available; it may be more transactional than manual deploy.)
- **Cross-platform paths**: use `python -c "import os; print(os.path.expanduser('<path>'))"` for `~`-resolution rather than relying on shell tilde expansion in passed-through Bash strings.
