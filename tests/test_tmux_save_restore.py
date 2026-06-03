# ABOUTME: Tests tmux-save.sh / tmux-restore.sh against a real, isolated tmux server.
# ABOUTME: Guards the destructive-wipe and cron/systemd-PATH regressions, plus a save→restore round trip.

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
SAVE = SCRIPTS / "tmux-save.sh"
RESTORE = SCRIPTS / "tmux-restore.sh"

pytestmark = pytest.mark.skipif(
    shutil.which("tmux") is None, reason="tmux not installed"
)


@pytest.fixture
def tmux_env(tmp_path):
    """Env that points tmux at a private socket and the save scripts at temp dirs.

    Every test gets its own tmux server (via a short TMUX_TMPDIR) and its own
    save/log paths, so the suite never touches the user's real ~/.tmux-save or
    their live tmux server. The socket dir is kept short to stay under the unix
    socket path-length limit; pytest's tmp_path can be too long for that.
    """
    sock_tmp = Path(tempfile.mkdtemp(prefix="tmuxtest-"))
    env = os.environ.copy()
    env["TMUX_TMPDIR"] = str(sock_tmp)
    env["TMUX_SAVE_DIR"] = str(tmp_path / "tmux-save")
    env["TMUX_SAVE_LOG"] = str(tmp_path / "tmux-save.log")
    env.pop("TMUX", None)  # don't inherit an outer tmux server (we run inside one a lot)
    yield env
    subprocess.run(["tmux", "kill-server"], env=env, capture_output=True, text=True)
    shutil.rmtree(sock_tmp, ignore_errors=True)


def tmux(env, *args):
    return subprocess.run(["tmux", *args], env=env, capture_output=True, text=True)


def run_save(env, extra_env=None):
    e = dict(env)
    if extra_env:
        e.update(extra_env)
    return subprocess.run(
        [str(SAVE)], env=e, capture_output=True, text=True,
        stdin=subprocess.DEVNULL, timeout=60,
    )


def run_restore(env, *args):
    return subprocess.run(
        [str(RESTORE), *args], env=env, capture_output=True, text=True,
        stdin=subprocess.DEVNULL, timeout=60,
    )


def test_scripts_are_executable():
    for s in (SAVE, RESTORE):
        assert s.exists(), f"{s} not found"
        assert os.access(s, os.X_OK), f"{s} is not executable"


def test_save_with_no_server_preserves_existing_save(tmux_env):
    """Regression: a save run while no tmux server is up must NOT destroy the
    previous good snapshot. (Old code wiped the save dir before checking.)"""
    save_dir = Path(tmux_env["TMUX_SAVE_DIR"])
    (save_dir / "pane_contents").mkdir(parents=True)
    (save_dir / "state.tsv").write_text("SENTINEL-GOOD-SAVE\n")
    (save_dir / "saved_at").write_text("2026-01-01 00:00:00\n")

    # No session created on this isolated socket → no server running.
    result = run_save(tmux_env)

    assert result.returncode == 1, (result.stdout, result.stderr)
    assert "no tmux server" in result.stdout.lower()
    # The good save must still be intact.
    assert (save_dir / "state.tsv").read_text() == "SENTINEL-GOOD-SAVE\n"


def test_save_captures_running_session(tmux_env, tmp_path):
    """Happy path: a running session is written to a complete snapshot, the log
    is appended, and no staging dir is left behind."""
    assert tmux(tmux_env, "new-session", "-d", "-s", "alpha", "-c", str(tmp_path)).returncode == 0

    result = run_save(tmux_env)

    assert result.returncode == 0, (result.stdout, result.stderr)
    save_dir = Path(tmux_env["TMUX_SAVE_DIR"])
    assert (save_dir / "saved_at").exists()
    assert "alpha" in (save_dir / "state.tsv").read_text()
    assert Path(tmux_env["TMUX_SAVE_LOG"]).exists()
    staging = save_dir.parent / (save_dir.name + ".staging")
    assert not staging.exists(), "staging dir should be swapped away, not left behind"


def test_save_succeeds_with_minimal_path(tmux_env, tmp_path):
    """Regression: under cron / the systemd shutdown unit, PATH is minimal and
    `rip` (in a user bin dir) is not on it. The save must still succeed because
    the script re-adds the user bin dirs itself."""
    rip = shutil.which("rip")
    if rip is None:
        pytest.skip("rip not installed")

    # Build a PATH that has tmux but NOT rip, so we isolate the PATH fix.
    rip_dir = os.path.dirname(rip)
    tmux_dir = os.path.dirname(shutil.which("tmux"))
    seen, minimal = set(), []
    for p in ["/usr/bin", "/bin", "/usr/sbin", "/sbin", tmux_dir]:
        if p != rip_dir and p not in seen:
            seen.add(p)
            minimal.append(p)
    minimal_path = ":".join(minimal)
    if shutil.which("tmux", path=minimal_path) is None:
        pytest.skip("cannot isolate rip from tmux on this PATH layout")
    if shutil.which("rip", path=minimal_path) is not None:
        pytest.skip("rip reachable without user bin dirs; cannot test the PATH fix")

    # Pre-seed an existing save so the swap-time `rip` of the old save fires.
    save_dir = Path(tmux_env["TMUX_SAVE_DIR"])
    (save_dir / "pane_contents").mkdir(parents=True)
    (save_dir / "state.tsv").write_text("old\n")
    assert tmux(tmux_env, "new-session", "-d", "-s", "beta", "-c", str(tmp_path)).returncode == 0

    result = run_save(tmux_env, extra_env={"PATH": minimal_path})

    assert result.returncode == 0, (result.stdout, result.stderr)
    assert "beta" in (save_dir / "state.tsv").read_text()


def test_restore_recreates_sessions(tmux_env, tmp_path):
    """Round trip: save two plain sessions, kill them, restore → both return."""
    wd = str(tmp_path)
    assert tmux(tmux_env, "new-session", "-d", "-s", "alpha", "-c", wd).returncode == 0
    assert tmux(tmux_env, "new-session", "-d", "-s", "beta", "-c", wd).returncode == 0
    assert run_save(tmux_env).returncode == 0

    tmux(tmux_env, "kill-server")

    result = run_restore(tmux_env, "-c", "0")  # -c 0: skip scrollback replay

    assert result.returncode == 0, (result.stdout, result.stderr)
    assert tmux(tmux_env, "has-session", "-t", "alpha").returncode == 0
    assert tmux(tmux_env, "has-session", "-t", "beta").returncode == 0


def test_restore_with_no_saved_state_errors(tmux_env):
    """No snapshot on disk → restore exits cleanly with a clear message."""
    result = run_restore(tmux_env, "-c", "0")
    assert result.returncode == 1
    assert "no saved state" in result.stdout.lower()
