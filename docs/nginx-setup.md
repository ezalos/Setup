# Nginx Reverse Proxy Setup (TinyButMighty)

Nginx on the Raspberry Pi acts as a reverse proxy, forwarding traffic to the GPU workstation (192.168.1.96) on the local network.

## Install

```bash
sudo apt-get install -y nginx libnginx-mod-stream
```

## Deploy Config

The configs are tracked in `dotfiles/nginx.conf` and `dotfiles/nginx_port_forward.conf`. Since they live in `/etc/nginx/` (root-owned), the dotfile deployer can't symlink them automatically. Deploy manually:

```bash
sudo cp ~/Setup/dotfiles/nginx.conf /etc/nginx/nginx.conf
sudo cp ~/Setup/dotfiles/nginx_port_forward.conf /etc/nginx/sites-available/port-forward.conf
sudo nginx -t && sudo systemctl restart nginx
```

## Current Config

### Port Forwarding (all to 192.168.1.96)

| Port | Forwards to | Protocol | Use |
|------|-------------|----------|-----|
| 22022 | :22 | TCP stream | SSH to workstation |
| 1111 | :1111 | TCP stream | — |
| 8188 | :8188 | TCP stream | ComfyUI |
| 3901 | :3901 | HTTP proxy | FastAPI |
| 80 | local | HTTP | Default nginx page |

### Architecture

- **TCP ports** (22022, 1111, 8188) use the `stream` block in `nginx.conf` for raw TCP forwarding with 1h timeouts.
- **HTTP port** (3901) uses a `server` block inside the `http` section of `nginx.conf` with proper proxy headers (`X-Real-IP`, `X-Forwarded-For`, etc.).
- `underscores_in_headers on` is enabled for API header compatibility.
- The `sites-available/port-forward.conf` file exists but is **not symlinked** into `sites-enabled/` — it was from an older HTTP-based config that was replaced by the stream blocks.

## Verify

```bash
sudo nginx -t                    # Test config syntax
sudo ss -tlnp | grep nginx      # Check listening ports
curl http://192.168.1.96:8642/health  # Test direct access to workstation
```
