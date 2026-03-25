#!/usr/bin/env bash

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

TIMEOUT=3
EXIT_CODE=0

# ── Load .env ────────────────────────────────────────────────────────────────
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
else
  echo -e "${RED}[ERROR]${NC} .env not found. Run setup.sh first."
  exit 1
fi

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

# HTTP health checks: name|health_url|display_url
HTTP_CHECKS=(
  "MLflow|http://localhost:${MLFLOW_PORT}/health|http://localhost:${MLFLOW_PORT}"
  "MinIO|http://localhost:${MINIO_API_PORT}/minio/health/live|http://localhost:${MINIO_CONSOLE_PORT}"
  "ChromaDB|http://localhost:${CHROMADB_PORT}/api/v2/heartbeat|http://localhost:${CHROMADB_PORT}"
  "LiteLLM|http://localhost:${LITELLM_PORT}/health/liveliness|http://localhost:${LITELLM_PORT}"
  "Grafana|http://localhost:${GRAFANA_PORT}/api/health|http://localhost:${GRAFANA_PORT}"
  "Prometheus|http://localhost:${PROMETHEUS_PORT}/-/healthy|http://localhost:${PROMETHEUS_PORT}"
  "Loki|http://localhost:${LOKI_PORT}/ready|http://localhost:${LOKI_PORT}"
  "Tempo|http://localhost:${TEMPO_PORT}/ready|http://localhost:${TEMPO_PORT}"
  "OTel-Collector|http://localhost:${OTEL_METRICS_PORT}/metrics|grpc://localhost:${OTEL_GRPC_PORT}"
  "RedisInsight|http://localhost:${REDISINSIGHT_PORT}/api/health|http://localhost:${REDISINSIGHT_PORT}"
  "ChromaDB-Admin|http://localhost:${CHROMADB_ADMIN_PORT}|http://localhost:${CHROMADB_ADMIN_PORT}"
  "Mongo-Express|http://localhost:${MONGO_EXPRESS_PORT}|http://localhost:${MONGO_EXPRESS_PORT}"
  "Traefik|http://localhost:${TRAEFIK_DASHBOARD_PORT}/api/rawdata|http://localhost:${TRAEFIK_DASHBOARD_PORT}"
)

for entry in "${HTTP_CHECKS[@]}"; do
  IFS='|' read -r svc health_url display_url <<< "$entry"
  if check_http "$health_url"; then
    row "$svc" "healthy" "$display_url"
  else
    row "$svc" "unreachable" "$display_url"
  fi
done

# Portainer (HTTPS)
if check_https "https://localhost:${PORTAINER_PORT}/api/system/status"; then
  row "Portainer" "healthy" "https://localhost:${PORTAINER_PORT}"
else
  row "Portainer" "unreachable" "https://localhost:${PORTAINER_PORT}"
fi

# PostgreSQL (TCP check)
if (echo > /dev/tcp/localhost/${POSTGRES_PORT}) 2>/dev/null; then
  row "PostgreSQL" "healthy" "postgresql://localhost:${POSTGRES_PORT}"
else
  row "PostgreSQL" "unreachable" "postgresql://localhost:${POSTGRES_PORT}"
fi

# Redis (TCP check)
if (echo > /dev/tcp/localhost/${REDIS_PORT}) 2>/dev/null; then
  row "Redis" "healthy" "redis://localhost:${REDIS_PORT}"
else
  row "Redis" "unreachable" "redis://localhost:${REDIS_PORT}"
fi

# MongoDB (TCP check)
if (echo > /dev/tcp/localhost/${MONGODB_PORT}) 2>/dev/null; then
  row "MongoDB" "healthy" "mongodb://localhost:${MONGODB_PORT}"
else
  row "MongoDB" "unreachable" "mongodb://localhost:${MONGODB_PORT}"
fi

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo -e "  ${GREEN}All services healthy.${NC}"
else
  echo -e "  ${RED}Some services are unreachable. Check logs: docker compose logs <service>${NC}"
fi
echo ""

exit $EXIT_CODE
