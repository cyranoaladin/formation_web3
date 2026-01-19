#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_deployment_normalize_${TS}.txt"

echo "STEP=021 deployment normalize" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha DEPLOYMENT.md)
echo "PRE DEPLOYMENT.md ${PRE}" | tee -a "$LOG" >/dev/null

python3 -c 'import os,sys; p="DEPLOYMENT.md"; t=open(p,encoding="utf-8").read(); orig=t.splitlines();
# Build canonical document (no unproven tech)
L=[]
L+=[ "# Déploiement", "" ]
L+=[ "## Prerequisites", "- Docker installé", "- Docker Compose installé", "- (optionnel) curl pour tester" ]
L+=[ "","## Local","commandes :","```bash","docker compose up -d --build","docker compose ps","```", "", "tests :","```bash","curl -sS http://localhost:8000/health","curl -sS http://localhost:3000/  # optionnel (UI dev)","```" ]
L+=[ "","## Server","- Ouvrir les ports 8000 et 3000","- Se positionner dans le répertoire du dépôt", "", "```bash","docker compose up -d --build","docker compose ps","```" ]
L+=[ "","## Rollback","```bash","docker compose down","docker image ls | head  # optionnel","```", "", "- Rollback simple = revenir au commit précédent et rebuild :","```bash","git checkout <commit>","docker compose up -d --build","```" ]
new="\n".join(L).rstrip()+"\n"
changed = int(new!=t)
removed = (len(orig)-len(new.splitlines())) if changed else 0
if changed:
    open(p,"w",encoding="utf-8").write(new)
print(f"CHANGED={changed}")
print(f"REMOVED_LINES_COUNT={removed}")
' | tee -a "$LOG" >/dev/null

POST=$(sha DEPLOYMENT.md)
echo "POST DEPLOYMENT.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
