#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_${TS}.txt"

sha() { sha256sum "$1" | awk '{print $1}'; }

pre_readme=$(sha README.md)
pre_arch=$(sha ARCHITECTURE.md)
echo "PRE README.md ${pre_readme}" | tee "$LOG" >/dev/null
echo "PRE ARCHITECTURE.md ${pre_arch}" | tee -a "$LOG" >/dev/null

# Corps minimal pour les sections à ajouter
READ_ME_ARCH=$'- Orchestration: docker-compose.yml\n- Ports: API 8000 (/health), UI 3000\n- Flux: upload_zip → queued → worker → run/proof_bundle'
READ_ME_API=$'- Service HTTP sur 8000\n- Endpoint santé: GET /health\n- Déclaré dans docker-compose.yml'
READ_ME_WORKER=$'- Traite la file queued\n- Exécute run/proof_bundle sur archives upload_zip'
READ_ME_UI=$'- Service sur port 3000 (développement)\n- Accessible en navigateur local'
READ_ME_RAG=$'- Présence d\'un pipeline RAG (cf. RAG.md)'

ARCH_ARCH=$'- Vue d\'ensemble composants: API, Worker, UI, RAG\n- Orchestration: docker-compose.yml'
ARCH_API=$'- Port 8000\n- Endpoint santé: GET /health'
ARCH_WORKER=$'- Consommation de la file queued\n- Étape: run/proof_bundle'
ARCH_UI=$'- Port 3000 (développement)'
ARCH_RAG=$'- Pipeline RAG (cf. RAG.md)'

ensure_section() {
  local file="$1" heading="$2" body="$3"
  python3 -c 'import sys,re; p,h,b=sys.argv[1:4];
from pathlib import Path
t=Path(p).read_text(encoding="utf-8")
if re.search(r"(?im)^##\s*"+re.escape(h)+r"\b", t):
    print("KEPT", h)
else:
    t=t.rstrip()+"\n\n## "+h+"\n"+b+"\n"
    Path(p).write_text(t, encoding="utf-8")
    print("ADDED", h)
' "$file" "$heading" "$body" | tee -a "$LOG" >/dev/null
}

# README.md
ensure_section README.md "Architecture" "$READ_ME_ARCH"
ensure_section README.md "API" "$READ_ME_API"
ensure_section README.md "Worker" "$READ_ME_WORKER"
ensure_section README.md "UI" "$READ_ME_UI"
ensure_section README.md "RAG" "$READ_ME_RAG"

# ARCHITECTURE.md
ensure_section ARCHITECTURE.md "Architecture" "$ARCH_ARCH"
ensure_section ARCHITECTURE.md "API" "$ARCH_API"
ensure_section ARCHITECTURE.md "Worker" "$ARCH_WORKER"
ensure_section ARCHITECTURE.md "UI" "$ARCH_UI"
ensure_section ARCHITECTURE.md "RAG" "$ARCH_RAG"

post_readme=$(sha README.md)
post_arch=$(sha ARCHITECTURE.md)
echo "POST README.md ${post_readme}" | tee -a "$LOG" >/dev/null
echo "POST ARCHITECTURE.md ${post_arch}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
