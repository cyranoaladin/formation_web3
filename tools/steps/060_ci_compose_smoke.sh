#!/usr/bin/env bash
# Step 060 — ci_compose_smoke
# Goal: Add GitHub Actions workflow that builds the compose stack (mongo, api, worker) and runs Step 048 smoke.
# Proofs: print workflow content, docker compose version, git status. No CI run here.

set -euo pipefail

mkdir -p .github/workflows

WF=".github/workflows/ci.yml"
cat >"${WF}" <<'YAML'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  smoke:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Show Docker versions
        run: |
          docker --version
          docker compose version

      - name: Build and start services (mongo, api, worker)
        run: docker compose up -d --build mongo api worker

      - name: Wait for API health
        run: |
          for i in $(seq 1 90); do
            if curl -sSf http://localhost:8000/health >/dev/null; then echo READY; break; fi
            sleep 1
          done
          curl -sS http://localhost:8000/health

      - name: Run E2E smoke (Step 048)
        run: ./tools/run.sh tools/steps/048_e2e_smoke_upload_to_proof.sh

      - name: Compose logs on failure
        if: failure()
        run: docker compose logs --tail=300 || true

      - name: Tear down
        if: always()
        run: docker compose down -v
YAML

# Proofs

echo "--- head -n 120 ${WF} ---"
sed -n '1,120p' "${WF}"

echo "--- docker compose version ---"
docker compose version || true

echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
