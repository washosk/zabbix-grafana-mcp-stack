#!/usr/bin/env bash
set -e

COMPOSE="docker compose -f docker-compose.zabbix-grafana-mcp.yml"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Zabbix + Grafana + MCP Stack Setup                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Install Docker first.${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose not found. Install Docker Compose first.${NC}"
    exit 1
fi

# --- Step 1: .env ----------------------------------------------------------
echo -e "${YELLOW}Step 1: Writing placeholder .env file...${NC}"
cat > .env << 'EOF'
# PostgreSQL password (used by Zabbix server and the database itself)
POSTGRES_PASSWORD=changeme-db-password

# Grafana admin password (default: admin)
GRAFANA_ADMIN_PASSWORD=admin

# Password for the 'grafana_ro' read-only user (Grafana → Zabbix PostgreSQL datasource)
GRAFANA_RO_PASSWORD=changeme-grafana-ro-password

# Zabbix Admin password (must match the Zabbix 'Admin' account; default: zabbix)
GRAFANA_ZABBIX_PASSWORD=zabbix

# MCP tokens — create in Step 4
ZABBIX_TOKEN=replace-with-real-zabbix-api-token
GRAFANA_TOKEN=replace-with-real-grafana-service-account-token

# Overrides
TIMEZONE=Europe/Madrid
EOF

echo -e "${GREEN}✓ .env created${NC}"
echo ""
echo -e "${YELLOW}  Set real passwords in .env for POSTGRES_PASSWORD and GRAFANA_RO_PASSWORD.${NC}"
echo -e "${YELLOW}  GRAFANA_ADMIN_PASSWORD is set to 'admin' by default.${NC}"
echo ""
read -r -p "Press Enter when ready to start the full stack..."

# --- Step 2: start stack ---------------------------------------------------
echo ""
echo -e "${YELLOW}Step 2: Starting all services (Zabbix + Grafana + MCP + Backup)...${NC}"
$COMPOSE up -d --build

# --- Step 3: wait for services ---------------------------------------------
echo ""
echo -e "${YELLOW}Step 3: Waiting for services to be ready...${NC}"
echo -n "  Grafana"
until curl -sf http://localhost:3000/api/health > /dev/null 2>&1; do
    echo -n "."; sleep 2
done
echo -e " ${GREEN}ready${NC}"

echo -n "  Zabbix Web UI"
until curl -sf http://localhost:8080/ > /dev/null 2>&1; do
    echo -n "."; sleep 2
done
echo -e " ${GREEN}ready${NC}"

# --- Step 4: token instructions --------------------------------------------
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Services Ready — Create API Tokens                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${CYAN}Zabbix Web UI:${NC}  http://localhost:8080  (Admin / zabbix)"
echo -e "${CYAN}Grafana:${NC}        http://localhost:3000  (admin / admin)"
echo ""
echo "CREATE ZABBIX API TOKEN:"
echo "  1. Log in to http://localhost:8080"
echo "  2. Go to: Administration → API tokens → Create API token"
echo "  3. Copy the token into .env: ZABBIX_TOKEN=<your-token>"
echo ""
echo "CREATE GRAFANA SERVICE ACCOUNT TOKEN:"
echo "  1. Log in to http://localhost:3000"
echo "  2. Go to: Administration → Service accounts → Add service account"
echo "  3. Add a token, copy it into .env: GRAFANA_TOKEN=<your-token>"
echo ""
echo -e "${YELLOW}  Save .env and press Enter to restart MCP servers with the new tokens.${NC}"
read -r -p "Press Enter when ready..."

# --- Step 5: restart MCP ---------------------------------------------------
echo ""
echo -e "${YELLOW}Step 5: Restarting MCP servers...${NC}"
$COMPOSE restart zabbix-mcp grafana-mcp

echo -n "  Zabbix MCP"
until curl -sf http://localhost:8001/health > /dev/null 2>&1; do
    echo -n "."; sleep 2
done
echo -e " ${GREEN}ready${NC}"

echo -n "  Grafana MCP"
until curl -sf http://localhost:8002/healthz > /dev/null 2>&1; do
    echo -n "."; sleep 2
done
echo -e " ${GREEN}ready${NC}"

# --- Show admin portal password --------------------------------------------
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Zabbix MCP Admin Portal                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${CYAN}URL:${NC}  http://localhost:9090"
echo ""
echo "The admin portal lets you manage Zabbix instances, API tokens,"
echo "rate limits, and MCP client access without editing config.toml."
echo ""
echo -e "${YELLOW}Auto-generated admin credentials:${NC}"
ADMIN_LINE=$($COMPOSE logs zabbix-mcp 2>/dev/null | grep -i "password\|admin\|credential\|login" | tail -5)
if [ -n "$ADMIN_LINE" ]; then
    echo "$ADMIN_LINE"
else
    echo "  (run the command below if credentials are not shown above)"
    echo "  $COMPOSE logs zabbix-mcp | grep -i password"
fi

# --- Final summary ---------------------------------------------------------
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  All Done                                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}MCP endpoints:${NC}"
echo "  Zabbix MCP:   http://localhost:8001/sse"
echo "  Grafana MCP:  http://localhost:8002/sse"
echo ""
echo -e "${GREEN}Register with Claude Code:${NC}"
echo "  \$ claude mcp add zabbix --transport sse http://localhost:8001/sse"
echo "  \$ claude mcp add grafana --transport sse http://localhost:8002/sse"
echo ""
echo -e "${GREEN}Register with VS Code / Cursor (settings.json):${NC}"
echo "  {"
echo "    \"mcp\": {"
echo "      \"servers\": {"
echo "        \"zabbix\": {\"type\": \"sse\", \"url\": \"http://localhost:8001/sse\"},"
echo "        \"grafana\": {\"type\": \"sse\", \"url\": \"http://localhost:8002/sse\"}"
echo "      }"
echo "    }"
echo "  }"
echo ""
echo -e "${GREEN}Useful commands:${NC}"
echo "  View status:  $COMPOSE ps"
echo "  View logs:    $COMPOSE logs -f"
echo "  Stop stack:   $COMPOSE down"
echo "  Full reset:   $COMPOSE down -v"
echo ""
