# ai-local-stack
Infraestructura compartida Docker Compose para proyectos GenAI/MLOps

## Stack
Docker Compose, PostgreSQL 16, MongoDB 7, Redis 7, MinIO, ChromaDB, MLflow, LiteLLM, Prometheus, Grafana, Loki, Promtail, Traefik v3, Portainer, RedisInsight, chromadb-admin, mongo-express

## Commands
docker compose up -d
docker compose down
docker compose ps

## Critical Rules
1. TODOS los servicios en red `shared-infra` (bridge)
2. Container names con prefijo `infra-`
3. Healthchecks en TODOS los servicios
4. Memory limits obligatorios en deploy.resources
5. OS target: Windows 11 + Docker Desktop (WSL2)

## Architecture
Config files: litellm/, prometheus/, grafana/, loki/, promtail/, postgres/
Scripts: setup.sh, stop.sh, status.sh
Docs: docs/connect-project.md, docs/dvc-setup.md

## Important
Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.