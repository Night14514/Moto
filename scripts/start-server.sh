#!/usr/bin/env bash
# Start MotoTalk signaling server (LAN-accessible).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/server"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created server/.env from example"
fi

mkdir -p data logs

if [[ ! -d node_modules ]]; then
  echo "Installing npm dependencies..."
  npm install
fi

# Prefer docker if requested
if [[ "${1:-}" == "docker" ]]; then
  docker compose up -d --build
  echo "Docker server up. Health:"
  sleep 2
  curl -s "http://127.0.0.1:3000/health" || true
  echo
  exit 0
fi

echo "Starting node server on 0.0.0.0:3000 ..."
exec node src/server.js
