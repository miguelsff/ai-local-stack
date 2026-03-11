#!/usr/bin/env bash
set -euo pipefail

HOSTS_ENTRY="127.0.0.1 mlflow.local minio.local grafana.local prometheus.local chroma.local llm.local redis.local chromadb-admin.local portainer.local"

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }

# ── Detect environment ───────────────────────────────────────────────────────
detect_env() {
  if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
    echo "wsl"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  else
    echo "other"
  fi
}

# ── Add hosts entries ────────────────────────────────────────────────────────
add_hosts() {
  local env
  env=$(detect_env)

  # Check if already present
  if grep -qF "mlflow.local" /etc/hosts 2>/dev/null; then
    success "Hosts entries already present — skipping."
    return
  fi

  case "$env" in
    wsl)
      # In WSL, also try to update the Windows hosts file
      local win_hosts
      win_hosts=$(wslpath "C:/Windows/System32/drivers/etc/hosts" 2>/dev/null || true)
      if [[ -n "$win_hosts" ]] && [[ -f "$win_hosts" ]]; then
        if grep -qF "mlflow.local" "$win_hosts" 2>/dev/null; then
          success "Windows hosts entries already present."
        else
          echo "$HOSTS_ENTRY" | sudo tee -a "$win_hosts" > /dev/null && \
            success "Added entries to Windows hosts file: $win_hosts" || \
            warn "Could not write to Windows hosts file. Add manually: $HOSTS_ENTRY"
        fi
      fi
      # Also add to WSL /etc/hosts
      echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts > /dev/null && \
        success "Added entries to WSL /etc/hosts."
      ;;
    linux)
      echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts > /dev/null && \
        success "Added entries to /etc/hosts."
      ;;
    *)
      warn "Could not auto-configure hosts. Add manually to your hosts file:"
      echo "  $HOSTS_ENTRY"
      ;;
  esac
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          ai-local-stack  ·  Setup                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Check .env exists
if [[ ! -f .env ]]; then
  warn ".env not found — copying from .env.example. Edit before continuing."
  cp .env.example .env
fi

# Check docker
if ! command -v docker &>/dev/null; then
  echo "ERROR: docker not found. Install Docker Desktop first." >&2
  exit 1
fi

info "Configuring /etc/hosts entries..."
add_hosts

# Build chromadb-admin if image doesn't exist
if ! docker image inspect local/chromadb-admin &>/dev/null; then
  info "Building chromadb-admin image (first time only)..."
  bash chromadb-admin/build.sh
fi

info "Starting all services..."
docker compose up -d

info "Waiting 30s for services to initialize..."
sleep 30

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  Service          │ Port  │ URL                                     ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  MLflow           │ 5000  │ http://localhost:5000                   ║"
echo "║  MinIO Console    │ 9001  │ http://localhost:9001                   ║"
echo "║  ChromaDB         │ 8000  │ http://localhost:8000                   ║"
echo "║  ChromaDB Admin   │ 3010  │ http://localhost:3010                   ║"
echo "║  LiteLLM          │ 4000  │ http://localhost:4000                   ║"
echo "║  Grafana          │ 3000  │ http://localhost:3000                   ║"
echo "║  Prometheus       │ 9090  │ http://localhost:9090                   ║"
echo "║  RedisInsight     │ 5540  │ http://localhost:5540                   ║"
echo "║  Traefik Dashboard│ 8080  │ http://localhost:8080                   ║"
echo "║  Portainer        │ 9443  │ https://localhost:9443                  ║"
echo "║  PostgreSQL       │ 5432  │ postgresql://localhost:5432             ║"
echo "║  Redis            │ 6379  │ redis://localhost:6379                  ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
success "Stack is up. Run './status.sh' to verify all services are healthy."
echo ""
