# ABOUTME: Confirms the seeded skill-global authority map passes its own md/yaml sync lint.
import subprocess, sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "lint_authority_map.py"

def test_seeded_map_in_sync():
    r = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
