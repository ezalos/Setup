#!/usr/bin/env python3
# ABOUTME: CLI to publish a local file behind a long-random-token URL on share.develle.fr
# ABOUTME: Uploads via scp to TinyButMighty:/srv/share/<token>/<filename> with an .expires file
"""
share-file <path> [--duration 1h] [--host HOST] [--remote-root /srv/share] [--base-url URL]

Generates a 32-char URL-safe random token, scp's the file to the remote share host,
writes an .expires timestamp, and prints the public URL.

Stdlib only.
"""
import argparse
import os
import re
import secrets
import shlex
import subprocess
import sys
import time
from pathlib import Path

DEFAULTS = {
    "host": "TinyButMighty",
    "remote_root": "/srv/share",
    "base_url": "https://share.develle.fr",
    "duration": "1h",
}

DURATION_RE = re.compile(r"^(\d+)([smhd])$")
UNIT_SECS = {"s": 1, "m": 60, "h": 3600, "d": 86400}


def parse_duration(s: str) -> int:
    m = DURATION_RE.match(s.strip().lower())
    if not m:
        raise ValueError(f"invalid duration {s!r}; use Ns/Nm/Nh/Nd, e.g. 1h, 30m, 2d")
    n, u = int(m.group(1)), m.group(2)
    if n <= 0:
        raise ValueError(f"duration must be positive: {s!r}")
    return n * UNIT_SECS[u]


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, **kw)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("path", type=Path, help="local file to share")
    p.add_argument("--duration", default=DEFAULTS["duration"],
                   help=f"link lifetime (default {DEFAULTS['duration']}); Ns/Nm/Nh/Nd")
    p.add_argument("--host", default=DEFAULTS["host"], help=f"ssh host (default {DEFAULTS['host']})")
    p.add_argument("--remote-root", default=DEFAULTS["remote_root"],
                   help=f"remote share root (default {DEFAULTS['remote_root']})")
    p.add_argument("--base-url", default=DEFAULTS["base_url"],
                   help=f"public base URL (default {DEFAULTS['base_url']})")
    args = p.parse_args()

    src = args.path.expanduser().resolve()
    if not src.is_file():
        p.error(f"not a file: {src}")

    duration_s = parse_duration(args.duration)
    token = secrets.token_urlsafe(24)  # 32 chars, 192 bits

    # Filename gets URL-encoded by browsers; keep the original on disk.
    filename = src.name
    remote_dir = f"{args.remote_root}/{token}"
    expires_at = int(time.time()) + duration_s

    # Create remote dir, scp file, write .expires — three ssh round-trips.
    run(["ssh", args.host, f"mkdir -p {shlex.quote(remote_dir)}"])
    run(["scp", "-q", str(src), f"{args.host}:{remote_dir}/"])
    run(["ssh", args.host, f"echo {expires_at} > {shlex.quote(remote_dir + '/.expires')}"])

    url = f"{args.base_url}/{token}/{filename}"
    print(url)
    sys.stderr.write(
        f"expires: {time.strftime('%Y-%m-%d %H:%M:%S %Z', time.localtime(expires_at))} "
        f"({args.duration})\n"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as e:
        sys.stderr.write(f"share-file: command failed: {e}\n")
        sys.exit(1)
    except ValueError as e:
        sys.stderr.write(f"share-file: {e}\n")
        sys.exit(2)
