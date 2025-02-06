# Dotfiles Manager

A Python-based tool to manage and sync dotfiles across different devices and operating systems.

## Features

- Manage dotfiles across different devices and operating systems
- Automatic path translation between different home directories
- Backup system for safe modifications
- Support for multiple devices with different configurations
- Automatic symlink creation and management

## Setup Local Environment

1. Create and activate a virtual environment using `uv`:
```bash
uv venv
source .venv/bin/activate
```

2. Install dependencies:
```bash
uv sync
```

## Usage

### Adding a New Dotfile

```bash
python -m src_dotfiles add /path/to/dotfile [--alias custom_name] [--force]
```

Example:
```bash
python -m src_dotfiles add ~/.zshrc
python -m src_dotfiles add ~/.config/nvim/init.vim --alias neovim_config
```

### Deploying Dotfiles

Deploy all dotfiles:
```bash
python -m src_dotfiles deploy
```

Deploy a specific dotfile:
```bash
python -m src_dotfiles deploy --alias zshrc
```

## Development

### Running Tests

Run the test suite with verbose output:
```bash
pytest -s -v tests/test_dotfiles.py
```

### Docker Development Environment

Build the Docker container:
```bash
docker compose build
```

Start a new container:
```bash
docker kill work.gpu  # Stop any existing container
docker compose up -d  # Start in detached mode
docker compose exec work.gpu zsh  # Open a shell in the container
```

## Project Structure

- `src_dotfiles/`: Main package directory
  - `__main__.py`: CLI entry point
  - `database.py`: Core database operations
  - `DotFile.py`: Dotfile management logic
  - `config.py`: Configuration handling
  - `models.py`: Pydantic models for data validation

- `tests/`: Test suite
  - `test_dotfiles.py`: Main test file

## Notes

- Backups are automatically created before any modifications
- Device-specific paths are automatically translated
- The metadata file keeps track of all dotfiles and their device-specific configurations