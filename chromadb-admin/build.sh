#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
REPO_URL="https://github.com/flanker/chromadb-admin.git"

echo "[INFO] Cloning chromadb-admin..."
rm -rf "$BUILD_DIR"
git clone --depth 1 "$REPO_URL" "$BUILD_DIR"

echo "[INFO] Building lightweight Docker image..."
docker build -t local/chromadb-admin -f "$SCRIPT_DIR/Dockerfile" "$BUILD_DIR"

echo "[OK]   Image built: local/chromadb-admin"
docker images local/chromadb-admin --format "Size: {{.Size}}"
