# Zabbix + Grafana + MCP Stack

A Docker Compose stack that runs Zabbix monitoring, Grafana, and MCP servers so AI assistants (Claude Code, VS Code Copilot, Cursor) can query your infrastructure directly.

## Services

| Service | Port | Description |
|---|---|---|
| Zabbix Web UI | 8080 | Zabbix frontend and JSON-RPC API |
| Zabbix Server | 10051 | Monitoring engine (binary protocol, internal) |
| Grafana | 3000 | Dashboard UI and API |
| Zabbix MCP | 8001 | MCP server for Zabbix (`/sse`, `/mcp`) — optional profile |
| Zabbix MCP Admin | 9090 | Admin portal for the Zabbix MCP server |
| Grafana MCP | 8002 | MCP server for Grafana (`/sse`) — optional profile |

The database (PostgreSQL + TimescaleDB) runs internally on the `zabbix-net` bridge network with no exposed port.

## Compose files

| File | Purpose |
|---|---|
| `docker-compose.zabbix-grafana-mcp.yml` | Full stack: Zabbix + Grafana + both MCP servers |
| `docker-compose.core.yml` | Core only: Zabbix + Grafana, no MCP servers |

Use `docker-compose.core.yml` if you only want the monitoring stack without AI integration.

## Prerequisites

- Docker and Docker Compose v2
- Internet access for the first `docker compose up` (pulls images, builds Zabbix MCP from GitHub)

## Quick start

### Option A: automated setup script

```bash
git clone https://github.com/washosk/zabbix-grafana-mcp-stack.git
cd zabbix-grafana-mcp-stack
./setup-zabbix-grafana-mcp.sh
```

The script writes a placeholder `.env`, starts the core services, and prints instructions for creating tokens and registering MCP servers.

### Option B: manual setup

#### 1. Clone and configure

```bash
git clone https://github.com/washosk/zabbix-grafana-mcp-stack.git
cd zabbix-grafana-mcp-stack
cp .env.example .env
```

Edit `.env` and set strong passwords for the database and Grafana:

```
POSTGRES_PASSWORD=your-strong-db-password
GRAFANA_ADMIN_PASSWORD=your-strong-grafana-password
```

You can leave the `ZABBIX_TOKEN` and `GRAFANA_TOKEN` as placeholders for now — you'll fill those in after the services start.

#### 2. Start the core stack

```bash
docker compose -f docker-compose.zabbix-grafana-mcp.yml up -d
```

This starts PostgreSQL, Zabbix Server, Zabbix Web UI, and Grafana. The MCP services require real API tokens, so get those next.

#### 3. Create a Zabbix API token

1. Open Zabbix at http://localhost:8080 (login: `Admin` / value of `POSTGRES_PASSWORD`)
2. Go to **Administration → API tokens → Create API token**
3. Name it (e.g. `mcp-server`), set an expiry or leave it unlimited, enable it
4. Copy the generated token into `.env`:
   ```
   ZABBIX_TOKEN=your-token-here
   ```

#### 4. Create a Grafana service account token

1. Open Grafana at http://localhost:3000 (login: `admin` / value of `GRAFANA_ADMIN_PASSWORD`)
2. Go to **Administration → Service accounts → Add service account**
3. Name it (e.g. `mcp`), set role to **Viewer** (or higher if you want write access)
4. Click **Add service account token**, copy the token into `.env`:
   ```
   GRAFANA_TOKEN=your-token-here
   ```

#### 5. Start the MCP servers

Both MCP services are in the `optional` profile so they only start when you explicitly request them, after tokens are configured:

```bash
docker compose -f docker-compose.zabbix-grafana-mcp.yml --profile optional up -d
```

Or start them individually:

```bash
docker compose -f docker-compose.zabbix-grafana-mcp.yml --profile optional up -d zabbix-mcp
docker compose -f docker-compose.zabbix-grafana-mcp.yml --profile optional up -d grafana-mcp
```

Verify everything is up:

```bash
docker compose -f docker-compose.zabbix-grafana-mcp.yml ps
```

Test the MCP endpoints:

```bash
curl http://localhost:8001/health   # Zabbix MCP
curl http://localhost:8002/healthz  # Grafana MCP
```

## Register MCP servers in your AI client

### Claude Code

```bash
claude mcp add zabbix --transport sse http://localhost:8001/sse
claude mcp add grafana --transport sse http://localhost:8002/sse
```

Or add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "zabbix": {
      "type": "sse",
      "url": "http://localhost:8001/sse"
    },
    "grafana": {
      "type": "sse",
      "url": "http://localhost:8002/sse"
    }
  }
}
```

### VS Code (GitHub Copilot)

Add to your VS Code `settings.json`:

```json
{
  "mcp": {
    "servers": {
      "zabbix": {
        "type": "sse",
        "url": "http://localhost:8001/sse"
      },
      "grafana": {
        "type": "sse",
        "url": "http://localhost:8002/sse"
      }
    }
  }
}
```

### Cursor / Windsurf / other editors

Use the SSE URLs:
- Zabbix: `http://localhost:8001/sse`
- Grafana: `http://localhost:8002/sse`

If your client supports Streamable HTTP sessions, use `/mcp` instead of `/sse`.

## Configuration

### config.toml

The Zabbix MCP server is configured through `config.toml`, which is mounted into the container. Changes take effect after restarting the service.

Key settings:

```toml
[server]
transport = "sse"        # "sse" or "http"
compact_output = true    # reduces token usage; LLM can override per-call
rate_limit = 300         # max Zabbix API calls/minute per session (0 = unlimited)

[admin]
enabled = true
port = 9090

[zabbix.production]
url = "http://zabbix-web:8080"
api_token = "${ZABBIX_TOKEN}"
read_only = false        # set to true to block all write operations
verify_ssl = false
```

You can add a second Zabbix instance (e.g. staging) by adding another `[zabbix.<name>]` section:

```toml
[zabbix.staging]
url = "https://zabbix-staging.example.com"
api_token = "${ZABBIX_STAGING_TOKEN}"
read_only = true
verify_ssl = true
```

### Admin portal

The admin portal runs at http://localhost:9090. On first start it auto-generates credentials and writes them into `config.toml`. Check the container logs to get the initial password:

```bash
docker compose -f docker-compose.zabbix-grafana-mcp.yml logs zabbix-mcp | grep -i password
```

## Security hardening

By default the MCP server accepts connections from anyone on the network. For production or shared environments, enable token authentication.

### Generate a token

```bash
python3 -c "
import secrets, hashlib
t = 'zmcp_' + secrets.token_hex(32)
h = hashlib.sha256(t.encode()).hexdigest()
print(f'Token: {t}')
print(f'Hash:  sha256:{h}')
"
```

### Add to config.toml

```toml
[tokens.claude]
name = "Claude Code"
token_hash = "sha256:<paste-hash-here>"
scopes = ["*"]
read_only = true
```

### Use in your MCP client

Pass the token in the Authorization header when registering the server:

```json
{
  "mcpServers": {
    "zabbix": {
      "type": "sse",
      "url": "http://localhost:8001/sse",
      "headers": {
        "Authorization": "Bearer zmcp_..."
      }
    }
  }
}
```

## Useful commands

```bash
# Start core stack
docker compose -f docker-compose.zabbix-grafana-mcp.yml up -d

# Start MCP servers (after tokens are configured in .env)
docker compose -f docker-compose.zabbix-grafana-mcp.yml --profile optional up -d

# View logs
docker compose -f docker-compose.zabbix-grafana-mcp.yml logs -f
docker compose -f docker-compose.zabbix-grafana-mcp.yml logs -f zabbix-mcp

# Restart after config.toml changes
docker compose -f docker-compose.zabbix-grafana-mcp.yml restart zabbix-mcp

# Stop all services
docker compose -f docker-compose.zabbix-grafana-mcp.yml down

# Stop and remove volumes (full reset, loses all Zabbix and Grafana data)
docker compose -f docker-compose.zabbix-grafana-mcp.yml down -v

# Rebuild Zabbix MCP image (after upstream updates)
docker compose -f docker-compose.zabbix-grafana-mcp.yml build --no-cache zabbix-mcp
```

## Notes

- **Zabbix MCP** is built from source ([initMAX/zabbix-mcp-server](https://github.com/initMAX/zabbix-mcp-server)) on first `docker compose up`. Subsequent starts use the cached image.
- **Grafana MCP** uses the official `grafana/mcp-grafana:latest` image.
- The `grafana-mcp` healthcheck may show `unhealthy` in `docker ps` — this is a known upstream probe issue; the service responds normally on port 8002.
- The `zabbix-server` healthcheck shows `unhealthy` — expected, it listens on a binary protocol port, not HTTP.
- `config.toml` is mounted writable so the admin portal can write back credentials on bootstrap. The file must be writable by uid 1000 on the host (the default on most desktop Linux systems).
- `.env` is in `.gitignore` and will never be committed. `.env.example` is the safe template to publish.

## License

MIT — see [LICENSE](LICENSE).
