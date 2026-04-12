# cloudflare-dns

Self-contained Cloudflare DNS record management via the API. Drop this directory into any project.

## Prerequisites

- `bash`, `curl`, `jq`
- A Cloudflare API token with **Zone:DNS:Edit** permission

## Quick Start

```bash
# 1. Export your token (or use direnv/.envrc)
export CLOUDFLARE_API_TOKEN="your-token-here"

# 2. Create your config from the example
cp dns.example.json dns.json
# Edit dns.json with your zone and records

# 3. Preview changes
./dns.sh status

# 4. Apply
./dns.sh sync
```

## Commands

| Command | Description |
|---------|-------------|
| `./dns.sh list` | List all DNS records in the zone |
| `./dns.sh status` | Dry-run — show what `sync` would create/update |
| `./dns.sh sync` | Idempotent apply — create missing, update changed, skip matching |
| `./dns.sh delete NAME TYPE [--yes]` | Delete a record (e.g. `./dns.sh delete old-app A --yes`) |
| `./dns.sh help` | Show usage |

## Config Format (`dns.json`)

```json
{
  "zone": "example.com",
  "records": [
    {
      "type": "CNAME",
      "name": "app",
      "content": "tunnel-id.cfargotunnel.com",
      "proxied": true,
      "comment": "App via Cloudflare Tunnel"
    },
    {
      "type": "A",
      "name": "api",
      "content": "1.2.3.4",
      "proxied": true
    }
  ]
}
```

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `zone` | yes | — | Domain name (zone ID auto-discovered) |
| `type` | yes | — | `A`, `AAAA`, `CNAME`, `TXT`, etc. |
| `name` | yes | — | Short name (`app`, not `app.example.com`). Use `@` for apex |
| `content` | yes | — | IP address, hostname, or text value |
| `proxied` | no | `true` | Cloudflare orange cloud on/off |
| `ttl` | no | `1` | TTL in seconds (`1` = auto, required when proxied) |
| `comment` | no | — | Note attached to the record in Cloudflare |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CLOUDFLARE_API_TOKEN` | API token (primary) |
| `CF_API_TOKEN` | API token (fallback) |
| `DNS_CONFIG` | Override config file path (default: `dns.json` next to script) |

## Adding to a New Project

1. Copy the `cloudflare-dns/` directory into your project
2. Add `cloudflare-dns/dns.json` to `.gitignore` (contains real IPs)
3. Create `dns.json` from the example, fill in your zone and records
4. Run `./dns.sh status` then `./dns.sh sync`

## Security

- `dns.json` should be **gitignored** — it may contain origin IPs that Cloudflare proxy is meant to hide
- `dns.example.json` uses placeholder values and is safe to commit
- The API token is read from environment variables, never stored in files
