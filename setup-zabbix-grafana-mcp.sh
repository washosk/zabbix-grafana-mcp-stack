#!/usr/bin/env bash
set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Zabbix + Grafana + MCP Stack Setup                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Install Docker first.${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose not found. Install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Writing placeholder .env file...${NC}"
echo -e "${YELLOW}  Edit .env and set strong passwords before starting MCP services.${NC}"
cat > .env << 'EOF'
# PostgreSQL password (used by Zabbix server, web UI, and the database itself)
POSTGRES_PASSWORD=changeme-db-password

# Grafana admin password (login at http://localhost:3000 with user "admin")
GRAFANA_ADMIN_PASSWORD=changeme-grafana-password

# Zabbix API token — create in Zabbix: Administration → API tokens
ZABBIX_TOKEN=replace-with-real-zabbix-api-token

# Grafana service account token — create in Grafana: Administration → Service accounts
GRAFANA_TOKEN=replace-with-real-grafana-service-account-token
EOF
echo -e "${GREEN}✓ .env created${NC}"

echo -e "${YELLOW}Step 2: Starting core services (Zabbix + Grafana)...${NC}"
docker compose -f docker-compose.zabbix-grafana-mcp.yml up -d

echo ""
echo -e "${YELLOW}Step 3: Waiting for services to be ready...${NC}"
sleep 10

echo ""
echo -e "${GREEN}✅ SETUP COMPLETE!${NC}"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Access Information                                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Zabbix Web UI:${NC}"
echo "  URL:      http://localhost:8080"
echo "  User:     Admin"
echo "  Password: value of POSTGRES_PASSWORD in .env"
echo ""
echo -e "${GREEN}Grafana:${NC}"
echo "  URL:      http://localhost:3000"
echo "  User:     admin"
echo "  Password: value of GRAFANA_ADMIN_PASSWORD in .env"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Next Steps                                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. CREATE ZABBIX API TOKEN (required for Zabbix MCP):"
echo "   - Log in: http://localhost:8080"
echo "   - Go to: Administration → API tokens → Create API token"
echo "   - Copy the token, update .env: ZABBIX_TOKEN=<your-token>"
echo ""
echo "2. CREATE GRAFANA SERVICE ACCOUNT TOKEN (required for Grafana MCP):"
echo "   - Log in: http://localhost:3000"
echo "   - Go to: Administration → Service accounts → Add service account"
echo "   - Add a token, update .env: GRAFANA_TOKEN=<your-token>"
echo ""
echo "3. START MCP SERVERS (after setting both tokens in .env):"
echo "   docker compose -f docker-compose.zabbix-grafana-mcp.yml --profile optional up -d"
echo ""
echo "4. REGISTER MCP SERVERS WITH CLAUDE CODE:"
echo "   $ claude mcp add zabbix --transport sse http://localhost:8001/sse"
echo "   $ claude mcp add grafana --transport sse http://localhost:8002/sse"
echo ""
echo "5. REGISTER WITH VS CODE / CURSOR:"
echo "   Add to settings.json:"
echo "   {"
echo "     \"mcp\": {"
echo "       \"servers\": {"
echo "         \"zabbix\": {\"type\": \"sse\", \"url\": \"http://localhost:8001/sse\"},"
echo "         \"grafana\": {\"type\": \"sse\", \"url\": \"http://localhost:8002/sse\"}"
echo "       }"
echo "     }"
echo "   }"
echo ""
echo "6. USEFUL COMMANDS:"
echo "   View logs:    docker compose -f docker-compose.zabbix-grafana-mcp.yml logs -f"
echo "   Stop stack:   docker compose -f docker-compose.zabbix-grafana-mcp.yml down"
echo "   Full reset:   docker compose -f docker-compose.zabbix-grafana-mcp.yml down -v"
echo "   Status:       docker compose -f docker-compose.zabbix-grafana-mcp.yml ps"
echo ""
