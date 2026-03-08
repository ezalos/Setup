# NAT Manager

CLI tool to manage port forwarding rules on SFR Box routers.

Uses the router's web API (reverse-engineered) with HMAC-SHA256 challenge-response authentication.

## Setup

```sh
cd nat_manager
uv sync
```

Add credentials to `.secrets.sh` (sourced by `.zshrc`):

```sh
export SFR_BOX_LOGIN="admin"
export SFR_BOX_PASSWORD="your_password"
```

## Usage

```sh
# List all port forwarding rules
uv run python nat.py list

# Add a rule (TCP by default)
uv run python nat.py add my_service 8080 74 8080

# Add a UDP rule
uv run python nat.py add dns 53 74 53 --proto udp

# Add a rule in disabled state
uv run python nat.py add staging 3000 74 3000 --disabled

# Enable / disable a rule (by name or index)
uv run python nat.py enable my_service
uv run python nat.py disable 3

# Delete a rule
uv run python nat.py delete my_service
```

### Arguments

**add**

| Argument     | Description                                      |
|-------------|--------------------------------------------------|
| `name`      | Rule name (max 20 chars)                         |
| `ext_port`  | External port (1-65535)                          |
| `ip`        | Destination IP — last octet (e.g. `74`) or full address (`192.168.1.74`) |
| `dst_port`  | Destination port (1-65535)                       |
| `--proto`   | Protocol: `tcp` (default), `udp`, or `both`      |
| `--disabled`| Create the rule in disabled state                |

**delete / enable / disable**

| Argument | Description              |
|----------|--------------------------|
| `rule`   | Rule name or index number |

### Environment Variables

| Variable          | Default       | Description          |
|-------------------|---------------|----------------------|
| `SFR_BOX_PASSWORD`| *(required)*  | Router admin password |
| `SFR_BOX_LOGIN`   | `admin`       | Router login          |
| `SFR_BOX_HOST`    | `192.168.1.1` | Router IP address     |

## Network Architecture

### Machines

| Hostname      | IP             | Role                         |
|---------------|----------------|------------------------------|
| TinyButMighty | 192.168.1.74   | Raspberry Pi — nginx reverse proxy |
| TheBeast      | 192.168.1.96   | Main workstation — runs services   |

Public IP: `<REDACTED_PUBLIC_IP>`

### Traffic Flow

Most services follow this path:

```
Internet → Router NAT → TinyButMighty (nginx) → TheBeast (service)
```

The router forwards external ports to the Pi (.74), and nginx proxies traffic to TheBeast (.96) on the appropriate port.

### Active NAT Rules

| #  | Name          | Ext Port | Dest IP | Dest Port | Notes                              |
|----|---------------|----------|---------|-----------|------------------------------------|
| 1  | ssh           | 22       | .74     | 22        | SSH to Pi (disabled)               |
| 2  | futurmaton    | 1111     | .74     | 1111      | nginx → TheBeast:1111              |
| 3  | comfyui       | 8188     | .74     | 8188      | nginx → TheBeast:8188              |
| 4  | joker         | 3901     | .74     | 3901      | nginx → TheBeast:3901 (FastAPI)    |
| 5  | ssh_the_beast | 22022    | .96     | 22        | Direct SSH to TheBeast (no nginx)  |
| 6  | slides        | 80       | .74     | 80        | nginx → TheBeast:8080 (Marp slides)|

### Nginx Config on TinyButMighty

- **Main config**: `/etc/nginx/nginx.conf` — stream blocks (TCP proxy) for ports 22022, 1111, 8188; http block for port 3901
- **Slides proxy**: `/etc/nginx/conf.d/slides.conf` — port 80 → TheBeast:8080
- Default site (`/etc/nginx/sites-enabled/default`) is disabled

### Cloudflare (develle.fr)

`slides.develle.fr` is served via Cloudflare proxy:

| Setting         | Value                    |
|-----------------|--------------------------|
| DNS record      | A `slides` → `<REDACTED_PUBLIC_IP>` (proxied) |
| SSL mode        | Flexible (HTTPS to Cloudflare, HTTP to origin) |
| API token       | Stored in `~/42/Markdowns2Teach/.envrc` as `CLOUDFLARE_API_TOKEN` |
| Token perms     | Zone:DNS:Edit, Zone:Zone:Read |

The Marp slide server must be running (`make serve` in `~/42/Markdowns2Teach`) for the site to work.

### Adding a New Service

1. Add NAT rule: `uv run python nat.py add <name> <ext_port> 74 <ext_port>`
2. Add nginx config on Pi: `ssh TinyButMighty` and create `/etc/nginx/conf.d/<name>.conf`
3. Reload nginx: `ssh TinyButMighty "sudo nginx -t && sudo systemctl reload nginx"`
4. (Optional) Add Cloudflare DNS record for a subdomain of `develle.fr`
