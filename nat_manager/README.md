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
