#!/usr/bin/env bash

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

TIMEOUT=3
EXIT_CODE=0

# ── Check HTTP endpoint ───────────────────────────────────────────────────────
check_http() {
  local url="$1"
  curl -sf --max-time "$TIMEOUT" "$url" -o /dev/null 2>/dev/null
}

check_https() {
  local url="$1"
  curl -sf --max-time "$TIMEOUT" -k "$url" -o /dev/null 2>/dev/null
}

# ── Print row ─────────────────────────────────────────────────────────────────
row() {
  local service="$1" status="$2" url="$3"
  local color
  if [[ "$status" == "healthy" ]]; then
    color=$GREEN
  elif [[ "$status" == "starting" ]]; then
    color=$YELLOW
  else
    color=$RED
    EXIT_CODE=1
  fi
  printf "  %-22s ${color}%-10s${NC} %s\n" "$service" "$status" "$url"
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Docker Compose Status${NC}"
echo "─────────────────────────────────────────────────────────────────────"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
  docker compose ps
echo ""
echo -e "${BOLD}Service Health Checks${NC}"
echo "─────────────────────────────────────────────────────────────────────"
printf "  %-22s %-10s %s\n" "SERVICE" "STATUS" "URL"
echo "  ──────────────────────────────────────────────────────────────────"

declare -A SERVICES=(
  ["MLflow"]="http://localhost:5000/health|http://localhost:5000"
  ["MinIO"]="http://localhost:9000/minio/health/live|http://localhost:9001"
  ["ChromaDB"]="http://localhost:8000/api/v2/heartbeat|http://localhost:8000"
  ["LiteLLM"]="http://localhost:4000/health/liveliness|http://localhost:4000"
  ["Grafana"]="http://localhost:3000/api/health|http://localhost:3000"
  ["Prometheus"]="http://localhost:9090/-/healthy|http://localhost:9090"
  ["Loki"]="http://localhost:3100/ready|http://localhost:3100"
  ["RedisInsight"]="http://localhost:5540/api/health|http://localhost:5540"
  ["ChromaDB-Admin"]="http://localhost:3010|http://localhost:3010"
  ["Mongo-Express"]="http://localhost:8081|http://localhost:8081"
  ["Traefik"]="http://localhost:8080/api/rawdata|http://localhost:8080"
)

# Ordered list for consistent output
ORDERED=(MLflow MinIO ChromaDB ChromaDB-Admin LiteLLM Grafana Prometheus Loki RedisInsight Mongo-Express Traefik)

for svc in "${ORDERED[@]}"; do
  IFS='|' read -r health_url display_url <<< "${SERVICES[$svc]}"
  if check_http "$health_url"; then
    row "$svc" "healthy" "$display_url"
  else
    row "$svc" "unreachable" "$display_url"
  fi
done

# Portainer (HTTPS)
if check_https "https://localhost:9443/api/system/status"; then
  row "Portainer" "healthy" "https://localhost:9443"
else
  row "Portainer" "unreachable" "https://localhost:9443"
fi

# PostgreSQL (TCP check)
if timeout "$TIMEOUT" bash -c "echo > /dev/tcp/localhost/5432" 2>/dev/null; then
  row "PostgreSQL" "healthy" "postgresql://localhost:5432"
else
  row "PostgreSQL" "unreachable" "postgresql://localhost:5432"
fi

# Redis (TCP check)
if timeout "$TIMEOUT" bash -c "echo > /dev/tcp/localhost/6379" 2>/dev/null; then
  row "Redis" "healthy" "redis://localhost:6379"
else
  row "Redis" "unreachable" "redis://localhost:6379"
fi

# MongoDB (TCP check)
if timeout "$TIMEOUT" bash -c "echo > /dev/tcp/localhost/27017" 2>/dev/null; then
  row "MongoDB" "healthy" "mongodb://localhost:27017"
else
  row "MongoDB" "unreachable" "mongodb://localhost:27017"
fi

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo -e "  ${GREEN}All services healthy.${NC}"
else
  echo -e "  ${RED}Some services are unreachable. Check logs: docker compose logs <service>${NC}"
fi
echo ""

exit $EXIT_CODE
