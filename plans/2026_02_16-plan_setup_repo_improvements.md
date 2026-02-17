# Plan: Setup Repo Improvements (4 Items + Security Draft)

## Context

Louis has 4 items to address in his dotfiles management repo:
1. README is outdated and incomplete — needs a full rewrite
2. Claude Code config files should be backed up (non-sensitive ones)
3. tmux should preserve current directory when creating new windows
4. nvim-lspconfig warns about Nvim 0.10 deprecation — pin now, upgrade later

Additionally, Louis wants a draft/proposal for securely storing sensitive info at various security levels.

---

## Item 1: README Full Rewrite

**File:** `/home/ezalos/Setup/README.md`

The current README has several issues:
- Doesn't mention wezterm, tmux, or nvim configs (all managed)
- Docker section is prominent but unrelated to the dotfiles purpose
- Doesn't explain that `meta_3.json` is the active metadata file
- Doesn't list managed dotfiles or devices
- `src_dotfiles/readme.md` is a stale personal note, not useful docs

**Plan:**
- Rewrite README.md with clear sections:
  - **What this repo does** (dotfiles manager for multiple devices/OS)
  - **Managed dotfiles** (list all: .zshrc, .tmux.conf, wezterm.lua, config_nvim, etc.)
  - **Quick start** (uv venv, uv sync, deploy)
  - **Adding a new dotfile** (with example)
  - **Deploying dotfiles** (all or specific)
  - **Project structure** (explain src_dotfiles/, dotfiles/, dotfiles/old/, scripts/, meta_3.json)
  - **Devices** (brief mention of multi-device support)
  - **Development** (tests, Docker environment)
- Remove or downweight Docker section (move to a sub-section)

---

## Item 2: Back Up Claude Code Config (Non-Sensitive)

**Files to back up:**
- `~/.claude/CLAUDE.md` — global instructions (NOT sensitive)
- `~/.claude/settings.json` — permissions, model, plugins (NOT sensitive)

**Files to NOT back up:**
- `~/.claude/.credentials.json` — auth token (SENSITIVE)
- `~/.claude/memory/` — Louis said skip (considers it sensitive)
- `~/.claude/history.jsonl` — conversation history (sensitive/large)
- `~/.claude/projects/` — per-project session data (large, sensitive)

**Plan:**
- Use the existing dotfiles system: `python -m src_dotfiles add ~/.claude/CLAUDE.md --alias claude_md`
- Use: `python -m src_dotfiles add ~/.claude/settings.json --alias claude_settings`
- This will copy them into `dotfiles/` and create symlinks, tracked in `meta_3.json`
- Verify they appear in the dotfiles system and can be deployed

---

## Item 3: tmux — New Window Keeps Current Directory

**File:** `/home/ezalos/Setup/dotfiles/.tmux.conf`

Currently, `Ctrl+a ; c` creates a new window that opens in the home directory (tmux default). Louis wants it to open in the current pane's working directory.

**Plan:**
- Add this line to the PANE MANAGEMENT section of `.tmux.conf`:
  ```
  bind c new-window -c "#{pane_current_path}"
  ```
- This rebinds `c` (new window) to pass the current pane's path
- Also add the same `-c "#{pane_current_path}"` to the split bindings for consistency:
  ```
  bind | split-window -h -c "#{pane_current_path}"
  bind - split-window -v -c "#{pane_current_path}"
  ```

**Verification:** After reloading tmux config (`prefix + r`), creating a new window from any directory should land in that same directory.

---

## Item 4: nvim-lspconfig Deprecation Warning

**File:** `/home/ezalos/Setup/dotfiles/config_nvim/lua/plugins.lua`

Nvim is v0.10.4. nvim-lspconfig >= v2.6.0 shows a deprecation warning for Nvim 0.10. The last clean version is v2.5.0.

### Phase A: Pin lspconfig to v2.5.0 (immediate fix)

Change the nvim-lspconfig plugin spec in `plugins.lua`:
```lua
{
  "neovim/nvim-lspconfig",
  tag = "v2.5.0",
  event = "BufRead",
  dependencies = { ... },
  config = function()
    require("lsp")
  end,
},
```

**Verification:** Open nvim — the deprecation message should be gone. LSP should still work for configured servers.

### Phase B: Upgrade Neovim to 0.11 (future task, NOT done now)

This is a separate future effort. Document it as a note:
- Download AppImage from GitHub releases (simplest for Ubuntu)
- Migrate LSP config from `require('lspconfig').server.setup{}` to `vim.lsp.config()` + `vim.lsp.enable()`
- Unpin lspconfig after migration
- Test all plugins for 0.11 compatibility

---

## Item 5: Security Draft — Encrypted Secrets Storage

**File to create:** `/home/ezalos/Setup/docs/encrypted-secrets-proposal.md`

This is a design document (NOT implementation), proposing different security levels for storing sensitive dotfiles/config in this public repo.

### Proposed Security Tiers:

**Tier 1 — .gitignore (current approach)**
- Files like `.secrets.sh`, `.credentials.json` are in `.gitignore`
- Pros: Simple, zero tooling
- Cons: No backup at all, no sync across machines, easy to accidentally commit
- Risk: Low (if careful), but no recovery if disk fails

**Tier 2 — Symmetric encryption (git-crypt or manual GPG)**
- Use `git-crypt` to transparently encrypt specific files in the repo
- Files are encrypted at rest in git, decrypted on checkout with a shared key
- Pros: Files are backed up and synced, transparent git workflow
- Cons: Single shared key, key distribution problem
- Good for: `.secrets.sh`, API tokens, non-critical credentials

**Tier 3 — GPG asymmetric encryption (git-crypt with GPG keys)**
- Same as Tier 2 but uses GPG key pairs instead of symmetric key
- Each device has its own GPG key, authorized in the repo
- Pros: No shared secret, per-device access control, key revocation
- Cons: GPG key management complexity, need to authorize each new device
- Good for: SSH key passphrases, important tokens

**Tier 4 — External secret manager (pass, 1Password CLI, Bitwarden CLI)**
- Secrets stored in a dedicated password manager, referenced by scripts
- `.secrets.sh` would call `pass show openclaw/gateway-token` instead of hardcoding
- Pros: Industry-standard security, audit trail, works across all machines
- Cons: Requires secret manager setup on each device, external dependency
- Good for: All secrets, especially if you already use a password manager

**Tier 5 — Hardware-backed (YubiKey + GPG or age + hardware token)**
- Encryption keys stored on hardware security module
- Pros: Highest security, keys can't be extracted
- Cons: Need physical hardware, complex setup
- Good for: Production credentials, SSH keys to critical infrastructure

The document will explain each tier with concrete tool recommendations and a suggested migration path (start at Tier 2 with git-crypt, upgrade as needed).

---

## Execution Order

1. **Item 4** — Pin nvim-lspconfig (smallest, most self-contained change)
2. **Item 3** — tmux directory fix (small, self-contained)
3. **Item 2** — Add Claude config to dotfiles system (uses the tool, creates entries in meta_3.json)
4. **Item 1** — README rewrite (benefits from Items 2-4 being done first, so we can document accurately)
5. **Item 5** — Write the security proposal document

## Verification

- **Item 1:** Read the new README, ensure it accurately describes the repo
- **Item 2:** Run `python -m src_dotfiles deploy --alias claude_md` and verify symlink
- **Item 3:** Reload tmux (`prefix + r`), create new window, check directory
- **Item 4:** Open nvim, confirm no deprecation message, confirm LSP works
- **Item 5:** Review the proposal document for completeness
