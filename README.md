# Zabbix + Grafana + MCP Stack

A Docker Compose stack that integrates Zabbix 7.0 monitoring, Grafana, and MCP servers so AI assistants (Claude Code, VS Code Copilot, Cursor) can query your infrastructure directly.

Tested on a clean install: Zabbix 7.0.25, TimescaleDB 2.22.0-pg16, Grafana latest.

---

## Services

| Container | Port | Description |
|---|---|---|
| `zabbix-postgres` | — (internal) | PostgreSQL 16 + TimescaleDB — Zabbix and Grafana backend |
| `zabbix-server` | 10051 | Zabbix monitoring engine |
| `zabbix-web` | 8080 | Zabbix UI + JSON-RPC API |
| `grafana` | 3000 | Grafana dashboard + auto-provisioned datasources |
| `zabbix-pg-backup` | — | Daily rolling `pg_dump` to `data/pg-backups/` |
| `zabbix-mcp` | 8001, 9090 | MCP server for Zabbix (`/sse`, `/mcp`) + admin portal |
| `grafana-mcp` | 8002 | MCP server for Grafana (`/sse`) |
| `zabbix-java-gateway` | 10052 | JMX monitoring gateway |
| `zabbix-snmptraps` | 162/udp | SNMP trap receiver |

## Repository layout

```
.
├── config/                          # Committed config — mounted into containers
│   ├── backup/
│   │   ├── Dockerfile               # Alpine pg_dump cron image
│   │   ├── backup.sh                # pg_dump script (schema-only for history/trends)
│   │   └── crontab                  # Daily 02:05 schedule
│   ├── grafana/
│   │   └── provisioning/
│   │       ├── datasources/
│   │       │   └── zabbix.yaml      # Auto-provisions Zabbix API + PostgreSQL datasources
│   │       └── plugins/
│   │           └── zabbix-app.yaml  # Enables alexanderzobnin-zabbix-app on startup
│   ├── postgres/
│   │   └── init-grafana.sh          # Creates grafana DB/user + grafana_ro at first PG init
│   └── snmptrapd.conf               # SNMP trap daemon config
├── config.toml                      # Zabbix MCP server config (writable)
├── Dockerfile.zabbix-mcp            # Builds the Zabbix MCP image from source
├── docker-compose.zabbix-grafana-mcp.yml   # Full stack
├── .env.example                     # Safe template — copy to .env and fill in
└── data/                            # Runtime data — gitignored
    └── pg-backups/                  # zbx_cfg_1.sql.gz … zbx_cfg_7.sql.gz
```

---

## Prerequisites

- Docker Engine 24+ and Docker Compose v2 (`docker compose`, not `docker-compose`)
- Internet access on first run (pulls images, builds Zabbix MCP from GitHub)
- Port 162/udp available on the host for SNMP traps (if needed)

---

## Quick start

### Step 1 — configure passwords

```bash
git clone https://github.com/washosk/zabbix-grafana-mcp-stack.git
cd zabbix-grafana-mcp-stack
cp .env.example .env
```

Edit `.env` and set **all** passwords before the first `up`:

```env
POSTGRES_PASSWORD=your-strong-db-password
GRAFANA_ADMIN_PASSWORD=admin                             # default for testing
GRAFANA_RO_PASSWORD=your-strong-ro-password              # read-only datasource user
GRAFANA_ZABBIX_PASSWORD=zabbix                           # must match Zabbix Admin password
TIMEZONE=Europe/Madrid                                   # affects cron schedule and logs
```

Set the MCP tokens too — the containers start regardless, but need tokens to connect:

```env
ZABBIX_TOKEN=your-zabbix-api-token     # create in Zabbix: Administration → API tokens
GRAFANA_TOKEN=your-grafana-sa-token    # create in Grafana: Administration → Service accounts
```

See [Step 4](#step-4--create-api-tokens-for-mcp-servers) for how to get those tokens.

> [!IMPORTANT]
> The Grafana DB users are created by `config/postgres/init-grafana.sh` on PostgreSQL's **first init**.
> If you change `GRAFANA_DB_PASSWORD` or `GRAFANA_RO_PASSWORD` after the first start, you must wipe the volume to re-init:
> `docker compose -f docker-compose.zabbix-grafana-mcp.yml down -v`

### Step 2 — start the stack

```bash
docker compose -f docker-compose.zabbix-grafana-mcp.yml up -d
```

This starts **all 9 containers**. Everything is fully functional immediately, though MCP servers will log connection errors until you add the tokens in Step 4.

Expected output after settling (~2 minutes):

```
NAME                   STATUS
grafana                Up 2 minutes (healthy)
grafana-mcp            Up 2 minutes (healthy)
zabbix-java-gateway    Up 2 minutes (healthy)
zabbix-pg-backup       Up 2 minutes (healthy)
zabbix-postgres        Up 2 minutes (healthy)
zabbix-server          Up 2 minutes (healthy)
zabbix-snmptraps       Up 2 minutes (healthy)
zabbix-mcp             Up 2 minutes (healthy)
zabbix-web             Up 2 minutes (healthy)
```

### Step 3 — verify Grafana datasources

Open Grafana at <http://localhost:3000> and log in with `admin` / `GRAFANA_ADMIN_PASSWORD`.

Go to **Connections → Data sources** — you should see two auto-provisioned datasources:

| Datasource | Type | Description |
|---|---|---|
| **Zabbix** | `alexanderzobnin-zabbix-datasource` | API connection (triggers/host data) |
| **Zabbix PostgreSQL** | `postgres` | Direct DB connection (SQL panels/TimescaleDB) |

Check that both show green. If the Zabbix API one fails, verify `GRAFANA_ZABBIX_PASSWORD` in `.env`.

### Step 4 — create API tokens for MCP servers

The MCP containers are already running. Add tokens so they can connect:

**Zabbix token:**
1. Log in to Zabbix at <http://localhost:8080> (`Admin` / `zabbix`)
2. Go to **Administration → API tokens → Create API token**
3. Name it `mcp-server`, set unlimited expiry, copy the token to `ZABBIX_TOKEN` in `.env`.

**Grafana token:**
1. Log in to Grafana at <http://localhost:3000>
2. Go to **Administration → Service accounts → Add service account**
3. Name it `mcp`, set role **Viewer**, click **Add service account token**, copy to `GRAFANA_TOKEN` in `.env`.

Restart the MCP containers after saving tokens:
`docker compose -f docker-compose.zabbix-grafana-mcp.yml restart zabbix-mcp grafana-mcp`

---

## Register MCP servers in your AI client

### Claude Code

```bash
claude mcp add zabbix --transport sse http://localhost:8001/sse
claude mcp add grafana --transport sse http://localhost:8002/sse
```

### VS Code (GitHub Copilot)

```json
{
  "mcp": {
    "servers": {
      "zabbix": { "type": "sse", "url": "http://localhost:8001/sse" },
      "grafana": { "type": "sse", "url": "http://localhost:8002/sse" }
    }
  }
}
```

### OpenCode (CLI Assistant)

OpenCode is a Go-based CLI assistant that supports remote MCP servers. You can use it with **OpenRouter** to access free-tier models (like Gemini or Llama).

1.  Create or edit `~/.opencode/opencode.json` (or use the provided [example](config/opencode.json.example)).
2.  Configure the `openai` provider to point to OpenRouter:

```json
{
  "model": "google/gemini-2.0-flash-exp:free",
  "provider": "openai",
  "openai": {
    "base_url": "https://openrouter.ai/api/v1",
    "api_key": "your-openrouter-key"
  },
  "mcp": [
    { "name": "zabbix", "type": "remote", "url": "http://localhost:8001/sse" },
    { "name": "grafana", "type": "remote", "url": "http://localhost:8002/sse" }
  ]
}
```

### Cursor / Windsurf / other editors

- **Zabbix**: `http://localhost:8001/sse`
- **Grafana**: `http://localhost:8002/sse`

---

## Configuration

### `.env` reference

| Variable | Required | Default | Description |
|---|---|---|---|
| `POSTGRES_PASSWORD` | ✅ | — | PostgreSQL password for the `zabbix` user |
| `GRAFANA_ADMIN_PASSWORD` | ✅ | `admin` | Grafana `admin` UI password |
| `GRAFANA_RO_PASSWORD` | ✅ | — | Password for `grafana_ro` read-only datasource user |
| `GRAFANA_ZABBIX_PASSWORD` | ✅ | `zabbix` | Zabbix Admin password (for Grafana datasource) |
| `ZABBIX_TOKEN` | MCP only | — | Zabbix API token for `zabbix-mcp` |
| `GRAFANA_TOKEN` | MCP only | — | Grafana service account token |
| `TIMEZONE` | | `Europe/Madrid` | Container timezone |

### Backup (`config/backup/`)

**Schedule:** Daily at 02:05 (`TIMEZONE` in `.env`).
**What:** Config data (hosts, items...) is fully dumped. High-volume tables (`history`, `events`) are schema-only.
**Files:** `data/pg-backups/zbx_cfg_[1-7].sql.gz` (7-day rotation).

Trigger an immediate dump:
`docker compose -f docker-compose.zabbix-grafana-mcp.yml exec zabbix-pg-backup /usr/local/bin/backup.sh`

---

## Useful commands

```bash
# Start all services
docker compose -f docker-compose.zabbix-grafana-mcp.yml up -d

# View logs
docker compose -f docker-compose.zabbix-grafana-mcp.yml logs -f

# Trigger manual backup
docker compose -f docker-compose.zabbix-grafana-mcp.yml exec zabbix-pg-backup /usr/local/bin/backup.sh

# Stop stack
docker compose -f docker-compose.zabbix-grafana-mcp.yml down

# Full reset (wipes all data/volumes)
docker compose -f docker-compose.zabbix-grafana-mcp.yml down -v
rm -rf data/pg-backups/
```

---

## Notes

- **Grafana Backend**: Uses the default internal SQLite database for simplicity.
- **Zabbix Server Health**: Lists as `healthy` if port 10051 is listening.
- **Zabbix MCP** is built from source ([initMAX/zabbix-mcp-server](https://github.com/initMAX/zabbix-mcp-server)) on first `up` using `python:3.12-alpine` as base. The built image is cached; subsequent starts are fast.
- **`data/` is gitignored** — backup files, any stray bind-mount directories. Never committed.
- **`.env` is gitignored** — use `.env.example` as the committed template.
- The Zabbix MCP container runs as non-root (`mcpuser`, uid 1000). The `config.toml` bind-mount must be writable by uid 1000 on the host (default on desktop Linux).

---

## License

MIT — see [LICENSE](LICENSE).
