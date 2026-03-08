# SFR Box NAT Manager — Design & Implementation Plan

## Context

Louis manages port forwarding rules on his SFR Box router (192.168.1.1) through a web UI at `/network/nat`. He wants a CLI tool to add/list/delete/enable/disable rules programmatically, so he (or Claude) can manage NAT rules without opening a browser.

The SFR Box has no documented API — we reverse-engineered the web UI's HTTP requests to build this tool.

## Design

### File: `scripts/nat.py`

Single-file Python CLI script. Dependencies: `requests`, `beautifulsoup4` (plus stdlib `hashlib`, `hmac`, `argparse`, `os`).

### CLI Interface

```
scripts/nat.py list
scripts/nat.py add <name> <ext_port> <ip_last_octet> <dst_port> [--proto tcp|udp|both] [--disabled]
scripts/nat.py delete <name_or_index>
scripts/nat.py enable <name_or_index>
scripts/nat.py disable <name_or_index>
```

### Authentication (Challenge-Response)

The SFR Box uses HMAC-SHA256 challenge-response auth:

1. POST `/login` with `action=challenge` (AJAX) → server returns XML/JSON with a `challenge` nonce
2. Compute: `hash = HMAC_SHA256(key=challenge, msg=SHA256(login)) + HMAC_SHA256(key=challenge, msg=SHA256(password))`
   - Both HMAC results are hex strings, concatenated
   - If this param order fails, swap key/msg
3. POST form to `/login` with fields:
   - `method=passwd`
   - `page_ref=/network/nat`
   - `zsid=<challenge>`
   - `hash=<computed_hash>`
   - `login=` (empty — cleared by JS)
   - `password=` (empty — cleared by JS)
4. Server returns 302 with `Set-Cookie: sid=...`

### NAT Operations

All operations POST to `/network/nat` with `content-type: application/x-www-form-urlencoded`.

**Common payload fields** (sent with every action):
- `port_list_tcp` — colon-separated existing TCP ports, e.g. `:22:1111:8188:`
- `port_list_udp` — colon-separated existing UDP ports, e.g. `:`
- `nat_rulename`, `nat_proto`, `nat_range`, `nat_extport`, `nat_dstip_p0-p3`, `nat_dstport`
- `nat_extrange_p0/p1`, `nat_dstrange_p0/p1` (empty for single port)
- `nat_active` — `on` or absent

**Action discriminators** (one per request):
- **Add**: `action_add=`
- **Delete**: `action_remove.<index>=`
- **Disable**: `action_disable.<index>=Disable`
- **Enable**: `action_enable.<index>=Enable`

### HTML Parsing (for list and state)

Table `#nat_config` has rows with `<td data-title="...">` cells:
- `#` → rule number (from `span.col_number`)
- `Name`, `Protocol`, `Type`, `External ports`, `IP address`, `Destination ports`
- `Activation` → contains button: `action_disable.N` (rule is enabled) or `action_enable.N` (rule is disabled)
- Last row (no `span.col_number`) is the "add new" form row — skip it

Rule index extracted from button `name` attribute (e.g., `action_disable.5` → index 5).

### Password Storage

Add to `.secrets.sh` (gitignored):
```bash
export SFR_BOX_PASSWORD="..."
export SFR_BOX_LOGIN="admin"  # optional, defaults to "admin"
```

Script reads `SFR_BOX_PASSWORD` and `SFR_BOX_LOGIN` from environment. Exits with error if password is missing.

### Constraints

- IP addresses constrained to `192.168.1.x` — CLI accepts last octet or full IP (validates prefix)
- Rule names max 20 chars
- Ports max 5 digits (1-65535)

## Implementation Steps

1. **Add env vars to `.secrets.sh`** — `SFR_BOX_PASSWORD`, `SFR_BOX_LOGIN`
2. **Create `scripts/nat.py`** with:
   - ABOUTME header comment
   - `SFRBoxNAT` class encapsulating session, auth, and operations
   - `login()` — challenge-response auth flow
   - `list_rules()` — GET page, parse HTML table, return list of rule dicts
   - `add_rule(name, ext_port, ip_last_octet, dst_port, proto, active)` — POST with `action_add`
   - `delete_rule(name_or_index)` — resolve to index, POST with `action_remove`
   - `enable_rule(name_or_index)` / `disable_rule(name_or_index)` — POST with `action_enable`/`action_disable`
   - `_build_port_lists()` — reconstruct `port_list_tcp`/`port_list_udp` from current rules
   - `_get_rule_by_name_or_index(identifier)` — lookup helper
   - `argparse` CLI with subcommands: `list`, `add`, `delete`, `enable`, `disable`
3. **Make executable** — `chmod +x scripts/nat.py`, add shebang `#!/usr/bin/env python3`
4. **Install deps** — `pip install requests beautifulsoup4` (or add to pyproject.toml)
5. **Test** — run `scripts/nat.py list` against the live router to verify auth + parsing

## Verification

1. `scripts/nat.py list` — should show the 6 existing rules in a formatted table
2. `scripts/nat.py add test_rule 9999 74 9999` — add a test rule, verify it appears in web UI
3. `scripts/nat.py disable test_rule` — disable it, verify in web UI
4. `scripts/nat.py enable test_rule` — re-enable it
5. `scripts/nat.py delete test_rule` — remove it, verify it's gone

## Key Files

- `scripts/nat.py` — **create** — the CLI tool
- `.secrets.sh` — **edit** — add SFR_BOX_PASSWORD and SFR_BOX_LOGIN env vars
