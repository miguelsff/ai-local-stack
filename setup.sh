#!/usr/bin/env bash
set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }

# ── Load .env ────────────────────────────────────────────────────────────────
load_env() {
  if [[ ! -f .env ]]; then
    warn ".env not found — copying from .env.example. Edit before continuing."
    cp .env.example .env
  fi
  # shellcheck disable=SC1091
  source .env
}

# ── Detect environment ───────────────────────────────────────────────────────
detect_env() {
  if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
    echo "wsl"
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "mingw"* ]]; then
    echo "gitbash"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  else
    echo "other"
  fi
}

# ── Add hosts entries ────────────────────────────────────────────────────────
add_hosts() {
  local hosts_entry="127.0.0.1 mlflow.local minio.local grafana.local prometheus.local chroma.local llm.local redis.local chromadb-admin.local portainer.local mongo.local tempo.local"
  local env
  env=$(detect_env)

  if grep -qF "mlflow.local" /etc/hosts 2>/dev/null; then
    success "Hosts entries already present — skipping."
    return
  fi

  case "$env" in
    wsl)
      local win_hosts
      win_hosts=$(wslpath "C:/Windows/System32/drivers/etc/hosts" 2>/dev/null || true)
      if [[ -n "$win_hosts" ]] && [[ -f "$win_hosts" ]]; then
        if grep -qF "mlflow.local" "$win_hosts" 2>/dev/null; then
          success "Windows hosts entries already present."
        else
          echo "$hosts_entry" | sudo tee -a "$win_hosts" > /dev/null && \
            success "Added entries to Windows hosts file: $win_hosts" || \
            warn "Could not write to Windows hosts file. Add manually: $hosts_entry"
        fi
      fi
      echo "$hosts_entry" | sudo tee -a /etc/hosts > /dev/null && \
        success "Added entries to WSL /etc/hosts."
      ;;
    linux)
      echo "$hosts_entry" | sudo tee -a /etc/hosts > /dev/null && \
        success "Added entries to /etc/hosts."
      ;;
    gitbash)
      warn "Add this line to C:\\Windows\\System32\\drivers\\etc\\hosts (run notepad as Admin):"
      echo "  $hosts_entry"
      ;;
    *)
      warn "Could not auto-configure hosts. Add manually to your hosts file:"
      echo "  $hosts_entry"
      ;;
  esac
}

# ── Check ports ──────────────────────────────────────────────────────────────
check_ports() {
  info "Checking port availability..."

  # Exclude ports already used by this stack
  local own_ports
  own_ports=$(docker compose ps --format '{{.Ports}}' 2>/dev/null | grep -oP '0\.0\.0\.0:\K[0-9]+' || true)

  # service_name|env_var_name|port_value
  local port_list=(
    "PostgreSQL|POSTGRES_PORT|${POSTGRES_PORT}"
    "Redis|REDIS_PORT|${REDIS_PORT}"
    "MongoDB|MONGODB_PORT|${MONGODB_PORT}"
    "Mongo Express|MONGO_EXPRESS_PORT|${MONGO_EXPRESS_PORT}"
    "MinIO API|MINIO_API_PORT|${MINIO_API_PORT}"
    "MinIO Console|MINIO_CONSOLE_PORT|${MINIO_CONSOLE_PORT}"
    "ChromaDB|CHROMADB_PORT|${CHROMADB_PORT}"
    "MLflow|MLFLOW_PORT|${MLFLOW_PORT}"
    "LiteLLM|LITELLM_PORT|${LITELLM_PORT}"
    "Loki|LOKI_PORT|${LOKI_PORT}"
    "Tempo|TEMPO_PORT|${TEMPO_PORT}"
    "OTel Collector gRPC|OTEL_GRPC_PORT|${OTEL_GRPC_PORT}"
    "OTel Collector HTTP|OTEL_HTTP_PORT|${OTEL_HTTP_PORT}"
    "OTel Metrics|OTEL_METRICS_PORT|${OTEL_METRICS_PORT}"
    "Prometheus|PROMETHEUS_PORT|${PROMETHEUS_PORT}"
    "Grafana|GRAFANA_PORT|${GRAFANA_PORT}"
    "RedisInsight|REDISINSIGHT_PORT|${REDISINSIGHT_PORT}"
    "ChromaDB Admin|CHROMADB_ADMIN_PORT|${CHROMADB_ADMIN_PORT}"
    "Traefik HTTP|TRAEFIK_HTTP_PORT|${TRAEFIK_HTTP_PORT}"
    "Traefik Dashboard|TRAEFIK_DASHBOARD_PORT|${TRAEFIK_DASHBOARD_PORT}"
    "Portainer|PORTAINER_PORT|${PORTAINER_PORT}"
  )

  local conflicts=()
  for entry in "${port_list[@]}"; do
    IFS='|' read -r svc var port <<< "$entry"
    echo "$own_ports" | grep -qx "$port" && continue
    if (echo >/dev/tcp/localhost/"$port") 2>/dev/null; then
      conflicts+=("  Port ${port} (${svc}) is in use  →  change ${var} in .env")
    fi
  done

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo ""
    warn "The following ports are already in use:"
    for c in "${conflicts[@]}"; do
      echo -e "  ${RED}${c}${NC}"
    done
    echo ""
    warn "Edit .env to change the conflicting ports, then re-run setup.sh"
    exit 1
  fi

  success "All ports are available."
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          ai-local-stack  ·  Setup                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

load_env

# Check docker
if ! command -v docker &>/dev/null; then
  echo "ERROR: docker not found. Install Docker Desktop first." >&2
  exit 1
fi

info "Configuring /etc/hosts entries..."
add_hosts

check_ports

# Build chromadb-admin if image doesn't exist
if ! docker image inspect local/chromadb-admin &>/dev/null; then
  info "Building chromadb-admin image (first time only)..."
  bash chromadb-admin/build.sh
fi

info "Starting all services..."
docker compose up -d

info "Waiting for services to initialize..."
sleep 30

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║  Service            │ Port     │ URL                                 ║"
echo "╠═══════════════════════════════════════════════════════════════════════╣"
printf "║  %-19s │ %-8s │ %-35s ║\n" "MLflow"             "$MLFLOW_PORT"             "http://localhost:$MLFLOW_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "MinIO Console"      "$MINIO_CONSOLE_PORT"      "http://localhost:$MINIO_CONSOLE_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "ChromaDB"           "$CHROMADB_PORT"            "http://localhost:$CHROMADB_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "ChromaDB Admin"     "$CHROMADB_ADMIN_PORT"      "http://localhost:$CHROMADB_ADMIN_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "LiteLLM"            "$LITELLM_PORT"             "http://localhost:$LITELLM_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "Grafana"            "$GRAFANA_PORT"             "http://localhost:$GRAFANA_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "Prometheus"         "$PROMETHEUS_PORT"           "http://localhost:$PROMETHEUS_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "Tempo"              "$TEMPO_PORT"                "http://localhost:$TEMPO_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "OTel Collector"     "$OTEL_GRPC_PORT/$OTEL_HTTP_PORT" "gRPC/HTTP"
printf "║  %-19s │ %-8s │ %-35s ║\n" "RedisInsight"       "$REDISINSIGHT_PORT"         "http://localhost:$REDISINSIGHT_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "Traefik Dashboard"  "$TRAEFIK_DASHBOARD_PORT"    "http://localhost:$TRAEFIK_DASHBOARD_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "Portainer"          "$PORTAINER_PORT"            "https://localhost:$PORTAINER_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "MongoDB"            "$MONGODB_PORT"              "mongodb://localhost:$MONGODB_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "Mongo Express"      "$MONGO_EXPRESS_PORT"        "http://localhost:$MONGO_EXPRESS_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "PostgreSQL"         "$POSTGRES_PORT"             "postgresql://localhost:$POSTGRES_PORT"
printf "║  %-19s │ %-8s │ %-35s ║\n" "Redis"              "$REDIS_PORT"                "redis://localhost:$REDIS_PORT"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
success "Stack is up. Run './status.sh' to verify all services are healthy."
echo ""
