# DVC con MinIO (ai-local-stack)

DVC corre en el host (fuera de Docker) y usa MinIO como remote de almacenamiento compatible con S3.

---

## Instalación

```bash
# Con pip (recomendado: en virtualenv del proyecto)
pip install "dvc[s3]"

# Verificar
dvc --version
```

---

## Configurar el remote apuntando a MinIO

Desde el directorio raíz de tu proyecto (donde está `.git`):

```bash
# 1. Inicializar DVC (si no existe)
dvc init

# 2. Agregar el remote MinIO
dvc remote add -d minio-local s3://datasets/dvc-store

# 3. Configurar el endpoint de MinIO (localhost cuando se corre desde el host)
dvc remote modify minio-local endpointurl http://localhost:9000

# 4. Credenciales (las del .env del stack)
dvc remote modify minio-local access_key_id minioadmin
dvc remote modify minio-local secret_access_key minioadmin_dev_pass

# 5. Verificar configuración
dvc remote list
cat .dvc/config
```

El archivo `.dvc/config` resultante:

```ini
[core]
    remote = minio-local
['remote "minio-local"']
    url = s3://datasets/dvc-store
    endpointurl = http://localhost:9000
    access_key_id = minioadmin
    secret_access_key = minioadmin_dev_pass
```

> Las credenciales quedan en `.dvc/config`. Para mantenerlas fuera del repo usa `dvc remote modify minio-local --local` (escribe en `.dvc/config.local`, ignorado por git).

---

## Uso básico

### Agregar datos al tracking de DVC

```bash
# Trackear un archivo o directorio
dvc add data/raw/dataset.csv

# Esto crea data/raw/dataset.csv.dvc y agrega data/raw/dataset.csv a .gitignore
git add data/raw/dataset.csv.dvc data/raw/.gitignore
git commit -m "Add raw dataset"

# Subir al remote (MinIO)
dvc push
```

### Recuperar datos

```bash
# En otra máquina o después de clonar
git clone <repo>
cd <repo>
dvc pull   # descarga desde MinIO
```

### Actualizar datos

```bash
# Modificar el archivo, luego:
dvc add data/raw/dataset.csv
git add data/raw/dataset.csv.dvc
git commit -m "Update dataset v2"
dvc push
```

---

## Pipeline básico

Define un pipeline reproducible en `dvc.yaml`:

```yaml
stages:
  prepare:
    cmd: python src/prepare.py
    deps:
      - src/prepare.py
      - data/raw/dataset.csv
    outs:
      - data/processed/clean.csv

  train:
    cmd: python src/train.py
    deps:
      - src/train.py
      - data/processed/clean.csv
    params:
      - params.yaml:
          - learning_rate
          - epochs
    outs:
      - models/model.pkl
    metrics:
      - metrics/scores.json:
          cache: false
```

```bash
# Ejecutar pipeline (solo etapas con cambios)
dvc repro

# Ver DAG del pipeline
dvc dag

# Ver métricas
dvc metrics show

# Comparar con versión anterior
dvc metrics diff
```

---

## Integración con MLflow

Para usar DVC + MLflow juntos en un experimento:

```python
import mlflow
import dvc.api

# Leer datos versionados por DVC desde MinIO
with dvc.api.open(
    "data/raw/dataset.csv",
    repo=".",
    remote="minio-local",
) as f:
    import pandas as pd
    df = pd.read_csv(f)

# Trackear experimento en MLflow
mlflow.set_tracking_uri("http://localhost:5000")
with mlflow.start_run():
    mlflow.log_param("dataset_rows", len(df))
    # ... entrenamiento y métricas
```

---

## Troubleshooting

**`ERROR: Failed to push data to the cloud`**
```bash
# Verificar que MinIO esté corriendo
curl http://localhost:9000/minio/health/live

# Verificar que el bucket exista
# MinIO crea el bucket 'datasets' automáticamente via minio-init
docker compose logs infra-minio-init
```

**`NoCredentialsError`**
```bash
# Verificar configuración del remote
dvc remote list
dvc remote modify minio-local access_key_id minioadmin
dvc remote modify minio-local secret_access_key minioadmin_dev_pass
```

**Conflicto con variables de entorno AWS**
```bash
# Si tienes AWS_ACCESS_KEY_ID en el entorno, puede interferir
# DVC da prioridad a la config del remote sobre el entorno
# Verificar con:
dvc remote modify minio-local --list
```
