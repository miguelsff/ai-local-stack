#!/usr/bin/env bash
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'

echo ""
echo -e "${CYAN}[INFO]${NC} Stopping ai-local-stack..."
docker compose down
echo -e "${GREEN}[OK]${NC}   All containers stopped. Volumes preserved."
echo ""
echo "To also remove volumes (WARNING: destroys all data):"
echo "  docker compose down -v"
echo ""
