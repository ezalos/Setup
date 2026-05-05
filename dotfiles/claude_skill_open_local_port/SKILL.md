---
name: open-local-port
description: Use when Louis asks to open an external port on his home network — e.g. "open port 9000", "expose service X to the internet", "add a NAT rule", "forward port", "let people reach my dev server". Wraps the SFR Box NAT manager and (when HTTP-shaped) the TinyButMighty nginx reverse proxy.
allowed-tools: Read, Edit, Write, Bash, Grep, AskUserQuestion
---

# open-local-port

Opens an external port on Louis's SFR Box and (when relevant) wires up the nginx reverse proxy on TinyButMighty so Internet traffic reaches a service on the LAN.

## Network architecture (memorize)

```
Internet ──► SFR Box (192.168.1.1) ──► TinyButMighty (192.168.1.74, nginx) ──► TheBeast (192.168.1.96, services)
                                  └──► TheBeast (192.168.1.96) directly  (e.g. SSH on ext 22022)
```

Public IP: redacted (see `~/Setup/nat_manager/README.md`). The `.74` Pi runs nginx on port 80 already (slides). Most HTTP services follow the proxied path; SSH-to-TheBeast goes direct on port 22022.

## Inputs to gather

Use AskUserQuestion if any are missing:

| Field | Notes |
|---|---|
| `name` | rule name, **≤20 chars**, e.g. `comfyui`, `share_https` |
| `ext_port` | external port (1-65535) |
| `dst` | `74` (TinyButMighty) or `96` (TheBeast). Last octet only also accepted by `nat.py`. |
| `dst_port` | usually same as `ext_port`; on `74` it's the nginx listen port |
| `proto` | `tcp` (default), `udp`, or `both` |
| `service_kind` | `tcp-stream` (raw passthrough) or `http` (so we add nginx) |

## Workflow

### 1. List current rules first (collision check)

```bash
cd ~/Setup/nat_manager && uv run python nat.py list
```

If the chosen `ext_port` or `name` is already taken, surface that to Louis before doing anything else.

### 2. Add the NAT rule

```bash
cd ~/Setup/nat_manager && uv run python nat.py add <name> <ext_port> <dst> <dst_port> --proto <proto>
```

Requires `SFR_BOX_PASSWORD` (and optionally `SFR_BOX_LOGIN`) in env — sourced from `~/.secrets.sh` by `.zshrc`. If unset, ask Louis to source it; do not prompt for the password directly.

Re-run `nat.py list` to confirm.

### 3. (HTTP only) Add nginx server block on TinyButMighty

If `dst=74` and `service_kind=http`, the Pi's nginx routes by port (and/or `server_name`). Create a config file:

```bash
ssh TinyButMighty "sudo tee /etc/nginx/conf.d/<name>.conf > /dev/null" <<'EOF'
server {
    listen <ext_port>;
    location / {
        proxy_pass http://192.168.1.96:<backend_port>;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
ssh TinyButMighty "sudo nginx -t && sudo systemctl reload nginx"
```

Template reference: `~/Setup/dotfiles/nginx_port_forward.conf`. If `nginx -t` fails, surface the error verbatim and stop — do not reload a broken config.

For `tcp-stream` (e.g. SSH), nginx config goes in the `stream {}` block of `/etc/nginx/nginx.conf`, not `/etc/nginx/conf.d/`. Edit the file directly via ssh in that case.

### 4. Verify reachability

From outside the LAN:

```bash
# from a non-home network
nc -zv <public-ip> <ext_port>            # plain TCP
curl -I http://<public-ip>:<ext_port>/   # HTTP
```

Or from inside the LAN, the public IP usually loops back through the router; test via a phone on cellular if uncertain.

If the user wants a `develle.fr` subdomain pointing at this port, hand off to the `link-develle-domain` skill afterwards.

## Reminders / gotchas

- Rule `1` (`ssh`, ext 22) is **intentionally disabled** — don't enable it without asking.
- `nat.py` actions hit the live router. There is no dry-run mode. Always `list` before `add`/`delete`.
- Don't pick `ext_port` 80 or 443 unless Louis explicitly says so — those are reserved for the slides/share stack.
- New ports may be blocked by Cloudflare if the destination is a `develle.fr` subdomain that's *proxied*: Cloudflare only proxies a fixed set of HTTP/HTTPS ports. Use a non-proxied (grey-cloud) DNS record for arbitrary ports.
