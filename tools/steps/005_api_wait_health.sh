#!/usr/bin/env bash
set -euo pipefail

for i in $(seq 1 120); do
  if curl -sS -m 1 http://localhost:8000/health >/dev/null 2>&1; then
    curl -sS -m 2 http://localhost:8000/health ; echo
    exit 0
  fi
  sleep 1
done

docker compose ps -a
docker compose logs --no-color --tail 300 api || true
docker compose exec -T api python -c "import app.main; print('IMPORT_OK')" 2>&1 || true
exit 1
