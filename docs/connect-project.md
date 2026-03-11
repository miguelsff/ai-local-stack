# Conectar un Proyecto a ai-local-stack

Todos los servicios del stack exponen sus puertos al host y comparten la red Docker `shared-infra`. Un proyecto externo puede conectarse de dos formas:

1. **Desde el host** (scripts, notebooks, apps locales) — usando `localhost:<puerto>`
2. **Desde otro contenedor** — uniéndose a la red `shared-infra` y usando los nombres de contenedor (`infra-postgres`, `infra-redis`, etc.)

---

## docker-compose.yml de un proyecto externo

```yaml
services:
  api:
    build: .
    env_file: .env
    networks:
      - shared-infra
    depends_on: []   # los servicios del stack ya están corriendo

  worker:
    build: .
    command: python worker.py
    env_file: .env
    networks:
      - shared-infra

networks:
  shared-infra:
    external: true   # <-- clave: referencia la red existente
```

### Variables de entorno recomendadas (`.env` del proyecto)

```env
# PostgreSQL
DATABASE_URL=postgresql://postgres:postgres_dev_pass@infra-postgres:5432/agents_db

# Redis
REDIS_URL=redis://:redis_dev_pass@infra-redis:6379/0

# ChromaDB
CHROMA_HOST=infra-chromadb
CHROMA_PORT=8000

# LiteLLM (OpenAI-compatible API)
LITELLM_BASE_URL=http://infra-litellm:4000/v1
LITELLM_API_KEY=sk-litellm-dev-master-key-change-me

# MLflow
MLFLOW_TRACKING_URI=http://infra-mlflow:5000

# MinIO / S3
AWS_ENDPOINT_URL=http://infra-minio:9000
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin_dev_pass
```

> Para conectar desde el **host** (notebooks, scripts locales), reemplaza los nombres de contenedor por `localhost`. Ej: `infra-postgres` → `localhost`.

---

## Ejemplos de código Python

### PostgreSQL con psycopg2 / SQLAlchemy

```python
import os
from sqlalchemy import create_engine, text

engine = create_engine(os.environ["DATABASE_URL"])

with engine.connect() as conn:
    result = conn.execute(text("SELECT version()"))
    print(result.fetchone())
```

### Redis con redis-py

```python
import os
import redis

r = redis.from_url(os.environ["REDIS_URL"], decode_responses=True)

r.set("hello", "world", ex=60)
print(r.get("hello"))  # "world"
```

### ChromaDB

```python
import os
import chromadb

client = chromadb.HttpClient(
    host=os.environ.get("CHROMA_HOST", "localhost"),
    port=int(os.environ.get("CHROMA_PORT", 8000)),
)

collection = client.get_or_create_collection("my_docs")

collection.add(
    documents=["Este es un documento de prueba"],
    ids=["doc1"],
)

results = collection.query(query_texts=["prueba"], n_results=1)
print(results)
```

### LiteLLM (vía cliente OpenAI)

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url=os.environ["LITELLM_BASE_URL"],
    api_key=os.environ["LITELLM_API_KEY"],
)

# Usar modelo local via Ollama
response = client.chat.completions.create(
    model="qwen3:4b",
    messages=[{"role": "user", "content": "Hola, ¿cómo estás?"}],
)
print(response.choices[0].message.content)

# Usar Claude via Anthropic (requiere ANTHROPIC_API_KEY en .env del stack)
response = client.chat.completions.create(
    model="claude-haiku-4-5",
    messages=[{"role": "user", "content": "Explica qué es un vector store."}],
)
print(response.choices[0].message.content)

# Embeddings
embedding = client.embeddings.create(
    model="nomic-embed-text",
    input="texto para embeber",
)
print(embedding.data[0].embedding[:5])
```

### MLflow — Tracking de experimentos

```python
import os
import mlflow

mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
mlflow.set_experiment("mi-experimento")

with mlflow.start_run():
    mlflow.log_param("learning_rate", 0.01)
    mlflow.log_param("epochs", 10)
    mlflow.log_metric("accuracy", 0.95)
    mlflow.log_metric("loss", 0.05)

    # Guardar artefacto en MinIO (configurado automáticamente)
    mlflow.log_text("resultados de prueba", "results.txt")
```

### MinIO / S3

```python
import os
import boto3

s3 = boto3.client(
    "s3",
    endpoint_url=os.environ["AWS_ENDPOINT_URL"],
    aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
    aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
)

# Listar buckets
buckets = s3.list_buckets()["Buckets"]
print([b["Name"] for b in buckets])

# Subir archivo
s3.upload_file("local_file.csv", "datasets", "uploads/local_file.csv")

# Descargar
s3.download_file("datasets", "uploads/local_file.csv", "descargado.csv")
```

---

## Dependencias Python recomendadas

```toml
# pyproject.toml
[project]
dependencies = [
    "sqlalchemy>=2.0",
    "psycopg2-binary",
    "redis>=5.0",
    "chromadb>=1.0",
    "openai>=1.0",
    "mlflow>=2.18",
    "boto3",
]
```

```bash
pip install sqlalchemy psycopg2-binary redis chromadb openai mlflow boto3
```
