---
name: share-file
description: Use when Louis asks to share a local file via a private link — e.g. "share this file", "send a temporary link", "upload X for someone", "give me a link that expires in 2h". Wraps the share-file CLI which uploads to TinyButMighty and serves via Caddy on share.develle.fr.
allowed-tools: Read, Bash, AskUserQuestion
---

# share-file

Generates a long-random-token URL that serves a single local file from `share.develle.fr` for a bounded time, then expires.

## Defaults

- **Duration**: 1 hour
- **Token**: 32-char URL-safe base64 (192 bits of entropy, generated on TheBeast)
- **URL shape**: `https://share.develle.fr/<token>/<filename>`
- **Backend**: scp → `tinybutmighty:/srv/share/<token>/<filename>`. Caddy serves it. A systemd timer prunes expired tokens every 5 minutes.

## Inputs to gather

| Field | Required | Default | Notes |
|---|---|---|---|
| `path` | yes | — | absolute or relative path to a single file |
| `duration` | no | `1h` | `Ns`/`Nm`/`Nh`/`Nd` — no combined units |

If Louis asks to share a directory or multiple files, suggest tar'ing them first into a single file. The CLI rejects non-files.

## Workflow

```bash
share-file <path> [--duration <Nh|Nm|Nd>]
```

The script (located at `~/Setup/share_file/share.py`, aliased to `share-file` in `.zshrc`) prints the URL on stdout and the expiry timestamp on stderr.

If the alias is missing for some reason, fall back to:

```bash
python3 ~/Setup/share_file/share.py <path> --duration <duration>
```

After running, copy the URL line and hand it to Louis. Do not click/curl the link to "verify" it — that would generate access logs in `/var/log/caddy/share.access.log` for an unintended viewer.

## When the share infra isn't bootstrapped yet

If `ssh TinyButMighty 'test -d /srv/share'` fails, or `share-file` errors with a connection issue, the share stack hasn't been set up. Walk Louis through `~/Setup/share_file/README.md` — do not start running its bootstrap commands without confirming first; they touch the Pi, the SFR Box, and Cloudflare DNS.

The bootstrap relies on the `open-local-port` and `link-develle-domain` skills for steps 4 and 5 respectively.

## Reminders / caveats

- **Token is the only secret.** Anyone with the URL can fetch the file until it expires. There is no per-recipient auth.
- **Files are unencrypted on the Pi** until cleanup. Don't share secrets without `age`-encrypting first.
- **Public IP is exposed** for `share.develle.fr` (record is not Cloudflare-proxied). Fine for casual sharing; flag it if Louis seems to want CF-level hiding.
- **Filename appears in the URL.** If the filename itself is sensitive (e.g. `internal-roadmap-q3.pdf`), suggest renaming before sharing.
- **No quota / size limit enforced.** The CLI happily uploads a 4GB file. Use judgment.
- **Default 1h is appropriate for most casual shares.** For longer lifetimes, prefer days (`2d`) over very long hours (`48h`) — same thing, but more readable.

## Verifying expiry

To confirm a link has expired (e.g. for forensics), `ssh TinyButMighty 'ls /srv/share/'` — the token directory should be gone after the next janitor pass (≤5 min after expiry).
