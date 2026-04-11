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
    echo -e "${RED}❌ Docker not found. Install Docker first.${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found. Install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Writing placeholder .env file...${NC}"
echo -e "${YELLOW}  (Replace values with real tokens before starting MCP services)${NC}"
cat > .env << 'EOF'
# Replace with a real Zabbix API token from Administration → API tokens
ZABBIX_TOKEN=replace-with-real-zabbix-api-token

# Replace with a real Grafana service account token from Administration → Service accounts
GRAFANA_TOKEN=replace-with-real-grafana-service-account-token
EOF
echo -e "${GREEN}✓ .env created${NC}"

echo -e "${YELLOW}Step 2: Starting core services and Grafana MCP...${NC}"
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
echo "  Password: zabbix"
echo ""
echo -e "${GREEN}Grafana:${NC}"
echo "  URL:      http://localhost:3000"
echo "  User:     admin"
echo "  Password: admin"
echo ""
echo -e "${GREEN}MCP Servers (for AI integration):${NC}"
echo "  Zabbix MCP:   http://localhost:8001/sse"
echo "  Grafana MCP:  http://localhost:8002/sse"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Next Steps                                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. CREATE GRAFANA SERVICE ACCOUNT TOKEN (required for Grafana MCP):"
echo "   - Log in: http://localhost:3000 (admin / admin)"
echo "   - Go to: Administration → Service accounts"
echo "   - Create account with Editor role, then add a token"
echo "   - Copy the token value"
echo "   - Update .env: GRAFANA_TOKEN=<your-token>"
echo "   - Restart: docker compose -f docker-compose.zabbix-grafana-mcp.yml restart grafana-mcp"
echo ""
echo "2. CREATE ZABBIX API TOKEN (required for Zabbix MCP):"
echo "   - Log in: http://localhost:8080 (Admin / zabbix)"
echo "   - Go to: Administration → API tokens"
echo "   - Create token named 'mcp-server'"
echo "   - Copy the token value"
echo "   - Update .env: ZABBIX_TOKEN=<your-token>"
echo "   - Start: docker compose -f docker-compose.zabbix-grafana-mcp.yml --profile optional up -d zabbix-mcp"
echo ""
echo "3. REGISTER MCP SERVERS WITH CLAUDE CODE:"
echo "   $ claude mcp add -s user zabbix --transport sse http://localhost:8001/sse"
echo "   $ claude mcp add -s user grafana --transport sse http://localhost:8002/sse"
echo ""
echo "4. REGISTER WITH VSCODE / ANTIGRAVITY / CURSOR:"
echo "   Create ~/.config/Code/User/mcp.json (VSCode)"
echo "   Create ~/.antigravity/mcp.json (Antigravity)"
echo "   Create ~/.cursor/mcp.json (Cursor)"
echo ""
echo "   Content:"
echo "   {"
echo "     \"servers\": {"
echo "       \"zabbix\": {\"type\": \"sse\", \"url\": \"http://localhost:8001/sse\"},"
echo "       \"grafana\": {\"type\": \"sse\", \"url\": \"http://localhost:8002/sse\"}"
echo "     }"
echo "   }"
echo ""
echo "5. USEFUL COMMANDS:"
echo "   View logs:        docker compose logs -f"
echo "   Stop stack:       docker compose down"
echo "   Full reset:       docker compose down -v"
echo "   Status:           docker compose ps"
echo ""
