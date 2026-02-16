# Setup — Dotfiles Manager

A Python-based tool to manage and sync dotfiles across multiple devices and operating systems. Dotfiles are stored as canonical copies in this repo and deployed as symlinks to their expected locations.

## Managed Dotfiles

| Alias | Deployed To | Description |
|-------|-------------|-------------|
| `.zshrc` | `~/.zshrc` | Zsh configuration |
| `.bashrc` | `~/.bashrc` | Bash configuration |
| `.tmux.conf` | `~/.tmux.conf` | tmux configuration |
| `wezterm.lua` | `~/.config/wezterm/wezterm.lua` | WezTerm terminal config |
| `config_nvim` | `~/.config/nvim` | Neovim configuration (full directory) |
| `.vimrc` | `~/.vimrc` | Vim configuration |
| `.p10k.zsh` | `~/.p10k.zsh` | Powerlevel10k prompt theme |
| `.neofetch` | `~/.config/neofetch/config.conf` | Neofetch system info display |
| `.gdbinit` | `~/.gdbinit` | GDB debugger init |
| `terminator` | `~/.config/terminator/config` | Terminator terminal config |
| `warp` | `~/.warp/launch_configurations/launch_config.yaml` | Warp terminal config |
| `jupyter_notebook_config.py` | `~/.jupyter/jupyter_notebook_config.py` | Jupyter config |
| `claude_md` | `~/.claude/CLAUDE.md` | Claude Code global instructions |
| `claude_settings` | `~/.claude/settings.json` | Claude Code settings |

## Quick Start

```bash
# Clone the repo
git clone <repo-url> ~/Setup
cd ~/Setup

# Create virtualenv and install dependencies
uv venv
source .venv/bin/activate
uv sync
```

## Usage

### Adding a New Dotfile

```bash
python -m src_dotfiles add /path/to/dotfile [--alias custom_name] [--force]
```

This will:
1. Copy the file into `dotfiles/` (using the alias as filename)
2. Back up the original to `dotfiles/old/`
3. Create a symlink from the original location to the repo copy
4. Register the dotfile in `meta_3.json`

Examples:
```bash
python -m src_dotfiles add ~/.zshrc
python -m src_dotfiles add ~/.config/wezterm/wezterm.lua --alias wezterm.lua
python -m src_dotfiles add ~/.claude/CLAUDE.md --alias claude_md
```

### Deploying Dotfiles

Deploy all dotfiles for the current device:
```bash
python -m src_dotfiles deploy
```

Deploy a specific dotfile by alias:
```bash
python -m src_dotfiles deploy --alias .zshrc
```

Deploying backs up any existing file at the target path, then creates a symlink pointing to the repo copy.

## Project Structure

```
Setup/
├── src_dotfiles/          # The dotfiles manager tool
│   ├── __main__.py        # CLI entry point (add, deploy)
│   ├── database.py        # Loads/saves meta_3.json, device lookups
│   ├── DotFile.py         # Backup, copy, symlink logic
│   ├── config.py          # Path resolution, device identifier
│   └── models.py          # Pydantic models for metadata
│
├── dotfiles/              # Canonical copies of all managed dotfiles
│   ├── meta_3.json        # Active metadata file (aliases, paths, devices, backups)
│   ├── old/               # Backups created before each deploy
│   ├── .zshrc, .tmux.conf, ...
│   └── config_nvim/       # Full directory dotfiles are supported
│
├── tests/                 # Test suite
├── scripts/               # Utility scripts
├── Installs/              # Package install scripts
├── docs/                  # Design documents and proposals
└── pyproject.toml         # Python project config (uv/pip)
```

### Key File: `dotfiles/meta_3.json`

This is the metadata database. It tracks:
- **Dotfile aliases** — each managed dotfile has a unique alias
- **Main path** — where the canonical copy lives in the repo (`dotfiles/<alias>`)
- **Per-device deploy paths** — each device has its own target path for each dotfile
- **Backup history** — timestamps and paths of backups created during deploys
- **Device registry** — known devices with their home paths and identifiers

Device identifiers are derived from hostname and username (e.g., `TheBeast.ezalos`, `rnd1.ldevelle`).

## Multi-Device Support

The system supports deploying the same dotfiles across different machines (Linux workstations, macOS laptops, remote servers). Each device is auto-detected by hostname/username and gets its own deploy paths in `meta_3.json`. Running `deploy` on any device will symlink files to that device's configured paths.

## Development

### Running Tests

```bash
pytest -s -v tests/test_dotfiles.py
```

### Docker Environment

Docker configs exist for reproducible development/testing environments:

```bash
docker compose -f docker-compose.gpu.yaml build
docker compose -f docker-compose.gpu.yaml up -d
docker compose -f docker-compose.gpu.yaml exec work.gpu zsh
```
