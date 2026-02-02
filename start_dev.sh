#!/usr/bin/env bash
set -euo pipefail

pids=()

cleanup() {
  for pid in "${pids[@]}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
}


# Auto-detect venv
PYTHON="python3"
if [ -f ".venv/bin/python" ]; then
  PYTHON="$(pwd)/.venv/bin/python"
  echo "✅ Using venv: $PYTHON"
else
  echo "⚠️  No .venv found, using system python3"
fi

trap cleanup EXIT INT TERM

(
  cd api
  API_PORT=8000
  $PYTHON - <<'PY' >/dev/null 2>&1 || API_PORT=8001
import socket
s = socket.socket()
s.bind(("127.0.0.1", 8000))
s.close()
PY
  echo "🚀 [API] Starting on port $API_PORT..."
  MONGODB_URI="mongodb://127.0.0.1:27017" $PYTHON -m uvicorn app.main:app --reload --host 127.0.0.1 --port "$API_PORT"
) &
pids+=("$!")

(
  cd worker
  echo "👷 [WORKER] Starting..."
  MONGODB_URI="mongodb://127.0.0.1:27017" $PYTHON worker.py
) &
pids+=("$!")

(
  cd ui
  API_PORT=8000
  $PYTHON - <<'PY' >/dev/null 2>&1 || API_PORT=8001
import socket
s = socket.socket()
s.bind(("127.0.0.1", 8000))
s.close()
PY
  echo "🎨 [UI] Starting Vite..."
  VITE_API_BASE="http://127.0.0.1:${API_PORT}" npm run dev -- --host 127.0.0.1 --port 5173
) &
pids+=("$!")

wait
