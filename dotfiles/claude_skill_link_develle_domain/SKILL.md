---
name: link-develle-domain
description: Use when Louis asks to add or change a DNS record on `develle.fr` — e.g. "make X.develle.fr point at Y", "add a subdomain", "set up a CNAME", "Cloudflare-proxy this", "what DNS records do we have". Wraps the idempotent dns.sh sync tool.
allowed-tools: Read, Edit, Write, Bash, Grep, AskUserQuestion
---

# link-develle-domain

Manages DNS records for the `develle.fr` zone via the Cloudflare API. The single source of truth is `~/Setup/cloudflare-dns/dns.json`; the script `dns.sh sync` does an idempotent diff-and-apply.

## Inputs to gather

| Field | Required | Default | Notes |
|---|---|---|---|
| `type` | yes | `A` | `A`, `AAAA`, `CNAME`, `TXT`, `MX`, `SRV`, etc. |
| `name` | yes | — | **short** name (`app`, not `app.develle.fr`). Use `@` for apex. |
| `content` | yes | — | IP, hostname, or text value |
| `proxied` | no | `true` (for A/AAAA/CNAME) | Cloudflare orange cloud on/off |
| `ttl` | no | `1` | seconds; `1` = auto. Required when `proxied=true`. |
| `comment` | no | — | annotation on Cloudflare side |

## Required env

`CLOUDFLARE_API_TOKEN` (Zone:DNS:Edit + Zone:Zone:Read). Per `~/Setup/nat_manager/README.md:117` it's stored in `~/42/Markdowns2Teach/.envrc`. If `echo $CLOUDFLARE_API_TOKEN` is empty, ask Louis to `direnv allow` that dir or source the file — never accept a token typed inline.

## Workflow

### 1. Read current state

```bash
cd ~/Setup/cloudflare-dns
cat dns.json | jq .            # local desired state
./dns.sh list                  # what Cloudflare actually has
```

Show Louis both, so it's clear whether the new record duplicates an existing one.

### 2. Edit `dns.json`

Append (or update) the record using the `Edit` tool, preserving JSON formatting and existing entries. Schema:

```json
{
  "type": "A",
  "name": "<short-name>",
  "content": "<ip-or-host>",
  "proxied": true,
  "comment": "<short purpose>"
}
```

### 3. Dry-run

```bash
cd ~/Setup/cloudflare-dns && ./dns.sh status
```

Show Louis the diff (records to create/update/skip). Stop here for review.

### 4. Apply (gated)

```bash
cd ~/Setup/cloudflare-dns && ./dns.sh sync
```

Then `./dns.sh list` to confirm the record landed.

## Combined flows

- **Need an external port too?** Run `open-local-port` first; if the port is non-standard (not 80/443), set `proxied: false` because Cloudflare's proxy only forwards a fixed list of HTTP/HTTPS ports.
- **For proxied A records**, `content` is still the **public IP** of the home connection (currently `REDACTED-HOME-IP` per the `vjaygent` record). Cloudflare hides it from outside DNS lookups.
- **Apex (`develle.fr` itself)** uses `name: "@"`. Do not write `develle.fr` as the name.

## Reminders

- `dns.json` is **gitignored** (it leaks origin IPs). Don't ever propose committing it.
- `dns.example.json` is the safe-to-commit template.
- Proxied records with `ttl != 1` will be rejected by Cloudflare.
- `dns.sh delete <name> <type>` exists but requires `--yes` to actually run; never call it without explicit user confirmation.
- Public IP of the home network can change (residential ISP). If a previously working A record stops resolving correctly, the IP may have rotated — check with `curl -s https://api.ipify.org` from TheBeast and update accordingly.
