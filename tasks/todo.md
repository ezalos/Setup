# Fix tmux-save destructive wipe + dead cron/systemd PATH (2026-06-03)

Plan: ../plans/2026_06_03-plan_fix_tmux_save_destructive_wipe.md

## Tasks

- [x] Step 1: add env overrides (TMUX_SAVE_DIR/TMUX_SAVE_LOG) to tmux-save.sh + TMUX_SAVE_DIR to tmux-restore.sh
- [x] Step 2: write tests/test_tmux_save_restore.py (T1–T5), run → T1 + T3 RED as expected
- [x] Step 3: GREEN T1 — reorder tmux-check before wipe + staging + atomic swap
- [x] Step 4: GREEN T3 — add PATH export covering cron/systemd
- [x] Step 5: full test run green (49 passed); confirmed real ~/.tmux-save behavior
- [x] Step 6: commit

## Review

Two compounding bugs fixed in `scripts/tmux-save.sh`:
1. **Destructive wipe** — it deleted `~/.tmux-save` before checking a server was
   up. Now: bail before touching anything if no server; build in
   `${SAVE_DIR}.staging` and swap in atomically only when complete.
2. **Dead under cron/systemd** — `rip` (in `~/.cargo/bin`) was off the minimal
   PATH, so every non-interactive save died at `rip: command not found`. Now the
   script exports the user bin dirs itself, covering cron, the systemd shutdown
   unit, and manual runs alike.

Tests: `tests/test_tmux_save_restore.py` drives a real, isolated tmux server (no
mocks) — regression tests for both bugs (each watched fail first) plus a
save→restore round trip. 6 new tests, full suite 49 passed.

Bonus: running the real `tsave` during verification captured a fresh snapshot of
the current sessions, so the Apr 4 → Jun 3 save gap is closed and there is now a
good snapshot on disk again.

Not changed (out of scope): `ps --ppid` / `ps -o comm=` in Claude detection are
GNU-flavored and may differ on macOS BSD `ps`; Claude-resume is best-effort.
