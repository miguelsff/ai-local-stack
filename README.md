# ai-local-stack

Infraestructura compartida Docker Compose para proyectos GenAI/MLOps en Windows 11 + Docker Desktop (WSL2).

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HOST WINDOWS 11                              │
│                                                                     │
│  Ollama :11434          DVC (CLI)          Git                      │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Docker Desktop (WSL2 backend)                    │  │
│  │                                                               │  │
│  │  ┌─────────────── shared-infra network ───────────────────┐  │  │
│  │  │                                                         │  │  │
│  │  │  DATA LAYER          ML LAYER         OBSERVABILITY     │  │  │
│  │  │  ┌──────────┐       ┌────────┐       ┌────────────┐    │  │  │
│  │  │  │ postgres │       │ mlflow │       │ prometheus │    │  │  │
│  │  │  │ :5432    │       │ :5000  │       │ :9090      │    │  │  │
│  │  │  └──────────┘       └────────┘       └────────────┘    │  │  │
│  │  │  ┌──────────┐       ┌────────┐       ┌────────────┐    │  │  │
│  │  │  │  redis   │       │litellm │       │  grafana   │    │  │  │
│  │  │  │  :6379   │       │ :4000  │       │  :3000     │    │  │  │
│  │  │  └──────────┘       └────────┘       └────────────┘    │  │  │
│  │  │  ┌──────────┐       ┌────────┐       ┌────────────┐    │  │  │
│  │  │  │  minio   │       │chroma  │       │    loki    │    │  │  │
│  │  │  │:9000/9001│       │ :8000  │       │   :3100    │    │  │  │
│  │  │  └──────────┘       └────────┘       └────────────┘    │  │  │
│  │  │                                                         │  │  │
│  │  │  MANAGEMENT: traefik :80/:8080 · portainer :9443        │  │  │
│  │  │  ADMIN UIs:  redisinsight :5540 · chromadb-admin :3010│  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Servicios

| Servicio | Puerto | URL Local | Descripción |
|---|---|---|---|
| PostgreSQL | 5432 | `postgresql://localhost:5432` | Base de datos relacional (mlflow_db + agents_db) |
| Redis | 6379 | `redis://localhost:6379` | Cache LRU + cache de LiteLLM |
| MinIO | 9000 / 9001 | http://localhost:9001 | Object storage compatible S3 |
| ChromaDB | 8000 | http://localhost:8000 | Vector store persistente |
| MLflow | 5000 | http://localhost:5000 | Tracking de experimentos ML |
| LiteLLM | 4000 | http://localhost:4000 | Proxy unificado de LLMs (OpenAI API compatible) |
| Prometheus | 9090 | http://localhost:9090 | Métricas |
| Grafana | 3000 | http://localhost:3000 | Dashboards (admin / ver .env) |
| Loki | 3100 | — | Agregación de logs |
| Promtail | — | — | Colector de logs Docker |
| ChromaDB Admin | 3010 | http://localhost:3010 | UI para ChromaDB (build local) |
| RedisInsight | 5540 | http://localhost:5540 | UI para Redis |
| Traefik | 80 / 8080 | http://localhost:8080 | Reverse proxy + dashboard |
| Portainer | 9443 | https://localhost:9443 | Gestión de contenedores |

## Quick Start

```bash
# 1. Clonar
git clone <repo-url> ai-local-stack && cd ai-local-stack

# 2. Configurar credenciales
cp .env.example .env
# Editar .env con tus API keys (OPENAI_API_KEY, ANTHROPIC_API_KEY)

# 3. Iniciar
chmod +x setup.sh stop.sh status.sh chromadb-admin/build.sh
./setup.sh

# 4. Verificar
./status.sh
```

## Comandos útiles

```bash
./setup.sh          # Primera vez: configura hosts + levanta stack
./stop.sh           # Detener todos los servicios (preserva datos)
./status.sh         # Health check de todos los servicios

docker compose up -d              # Levantar
docker compose down               # Detener
docker compose ps                 # Estado
docker compose logs -f infra-mlflow   # Logs de un servicio
docker compose restart infra-litellm  # Reiniciar un servicio
```

## Conectar un proyecto externo

En el `docker-compose.yml` de tu proyecto agrega:

```yaml
services:
  my-app:
    build: .
    networks:
      - shared-infra
    environment:
      DATABASE_URL: postgresql://postgres:postgres_dev_pass@infra-postgres:5432/agents_db
      REDIS_URL: redis://:redis_dev_pass@infra-redis:6379/0
      CHROMA_HOST: infra-chromadb
      CHROMA_PORT: 8000
      LITELLM_BASE_URL: http://infra-litellm:4000/v1
      MLFLOW_TRACKING_URI: http://infra-mlflow:5000

networks:
  shared-infra:
    external: true
```

Ver [`docs/connect-project.md`](docs/connect-project.md) para ejemplos de código Python.

## Budget RAM

| Servicio | Límite |
|---|---|
| postgres | 512 MB |
| minio | 512 MB |
| chromadb | 512 MB |
| redis | 192 MB |
| loki | 192 MB |
| mlflow | 1 GB |
| litellm | 512 MB |
| prometheus | 256 MB |
| grafana | 256 MB |
| chromadb-admin | 64 MB |
| redisinsight | 128 MB |
| traefik | 64 MB |
| portainer | 64 MB |
| promtail | 64 MB |
| minio-init | 64 MB |
| **Total** | **~4.2 GB** |

## Servicios en Host (fuera de Docker)

| Servicio | Puerto | Notas |
|---|---|---|
| **Ollama** | 11434 | Accesible desde containers via `host.docker.internal:11434` |
| **DVC** | — | CLI local; usa MinIO como remote S3. Ver [`docs/dvc-setup.md`](docs/dvc-setup.md) |

## Traefik — Dominios locales

Agrega a `C:\Windows\System32\drivers\etc\hosts` (como Administrador):

```
127.0.0.1 mlflow.local minio.local grafana.local prometheus.local chroma.local llm.local redis.local chromadb-admin.local portainer.local
```

Luego accede por nombre: http://mlflow.local, http://grafana.local, etc.

## Troubleshooting

**`infra-mlflow` no conecta a postgres**
```bash
docker compose logs infra-mlflow | grep -i error
# Solución: esperar que postgres esté healthy antes de reiniciar mlflow
docker compose restart infra-mlflow
```

**MinIO healthcheck falla en arranque**
```bash
# Normal en el primer inicio — MinIO tarda ~15s en estar listo
docker compose logs infra-minio
```

**Volúmenes ocupan mucho espacio**
```bash
docker system df          # Ver uso de disco
docker compose down -v    # PELIGRO: elimina todos los datos
```

**Puerto ocupado (ej. 5432 ya en uso)**
```bash
# En Windows, verificar proceso:
netstat -ano | findstr :5432
# Cambiar el puerto en docker-compose.yml: "5433:5432"
```

**Promtail no recolecta logs en WSL2**
```bash
# Verificar que /var/run/docker.sock sea accesible
ls -la /var/run/docker.sock
# Docker Desktop debe tener habilitado: Settings > General > Expose daemon on tcp://...
```
