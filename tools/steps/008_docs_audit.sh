#!/usr/bin/env bash
set -euo pipefail

# Step 008 — doc-audit ciblé
# Objectif: auditer uniquement les fichiers .md hors .warp/
# - Détecter sections manquantes (pour README.md et ARCHITECTURE.md)
# - Détecter redondances (titres dupliqués)
# - Détecter incohérences avec l'architecture réelle (api / worker / ui / rag)
# - Aucune modification de fichiers — produire un rapport factuel

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
OUT="tools/logs/docs_audit_${TS}.txt"

# Déterminer l'architecture réelle
api_present=0;   [[ -d api    ]] && api_present=1
worker_present=0;[[ -d worker ]] && worker_present=1
ui_present=0;    [[ -d ui     ]] && ui_present=1
rag_present=0;   { [[ -d rag ]] || [[ -f RAG.md ]]; } && rag_present=1

present_list=()
[[ $api_present -eq 1 ]] && present_list+=(api)
[[ $worker_present -eq 1 ]] && present_list+=(worker)
[[ $ui_present -eq 1 ]] && present_list+=(ui)
[[ $rag_present -eq 1 ]] && present_list+=(rag)

{
  echo "Doc audit (markdown, hors .warp/) — $(date -Iseconds)"
  echo "Sous-systèmes détectés: ${present_list[*]:-none}"
  echo
} | tee "$OUT" >/dev/null

lower() { awk '{print tolower($0)}'; }
trim() { sed -E 's/^\s+//; s/\s+$//'; }

has_heading() {
  local file="$1"; shift
  local pat="$1"
  grep -qiE "^#{1,6}[[:space:]]*${pat}([[:space:]]|$)" "$file" 2>/dev/null
}

list_duplicate_headings() {
  local file="$1"
  # Liste des titres (sans #) en minuscules, compte >1 => redondance
  grep -iE "^#{1,6}[[:space:]]+" "$file" 2>/dev/null \
    | sed -E 's/^#+[[:space:]]+//' \
    | lower | trim \
    | awk 'NF{c[$0]++} END{for(k in c) if (c[k]>1) printf "%s x%d\n", k, c[k]}'
}

# Itérer uniquement les .md racine (hors .warp/)
shopt -s nullglob
md_files=( *.md )
shopt -u nullglob

for f in "${md_files[@]}"; do
  echo "FILE: $f" | tee -a "$OUT" >/dev/null
  issues=0

  # 1) Sections manquantes (seulement pour README.md et ARCHITECTURE.md)
  if [[ "$f" == "README.md" || "$f" == "ARCHITECTURE.md" ]]; then
    missing=()
    # Architecture globale
    if ! has_heading "$f" "[Aa]rchitecture"; then missing+=("Architecture"); fi
    # Sous-systèmes présents => exiger un titre dédié
    [[ $api_present -eq 1    ]] && { has_heading "$f" "api"    || missing+=("API"); }
    [[ $worker_present -eq 1 ]] && { has_heading "$f" "worker" || missing+=("Worker"); }
    [[ $ui_present -eq 1     ]] && { has_heading "$f" "ui|front" || missing+=("UI"); }
    [[ $rag_present -eq 1    ]] && { has_heading "$f" "rag"    || missing+=("RAG"); }

    if (( ${#missing[@]} > 0 )); then
      echo "- MISSING_SECTIONS: ${missing[*]}" | tee -a "$OUT" >/dev/null
      issues=1
    fi
  fi

  # 2) Redondances (titres dupliqués)
  dups=$(list_duplicate_headings "$f" || true)
  if [[ -n "${dups:-}" ]]; then
    echo "- REDUNDANT_HEADINGS:" | tee -a "$OUT" >/dev/null
    while IFS= read -r line; do
      [[ -n "$line" ]] && echo "  * $line" | tee -a "$OUT" >/dev/null
    done <<< "$dups"
    issues=1
  fi

  # 3) Incohérences: mention d'un sous-système absent
  absent_notes=()
  [[ $api_present    -eq 0 ]] && { has_heading "$f" "api"    && absent_notes+=("mentions API mais pas présent"); }
  [[ $worker_present -eq 0 ]] && { has_heading "$f" "worker" && absent_notes+=("mentions Worker mais pas présent"); }
  [[ $ui_present     -eq 0 ]] && { has_heading "$f" "ui|front" && absent_notes+=("mentions UI mais pas présent"); }
  [[ $rag_present    -eq 0 ]] && { has_heading "$f" "rag"    && absent_notes+=("mentions RAG mais pas présent"); }
  if (( ${#absent_notes[@]} > 0 )); then
    echo "- ARCH_INCONSISTENCY: ${absent_notes[*]}" | tee -a "$OUT" >/dev/null
    issues=1
  fi

  if [[ $issues -eq 0 ]]; then
    echo "- OK: none" | tee -a "$OUT" >/dev/null
  fi
  echo | tee -a "$OUT" >/dev/null

done

echo "REPORT=$OUT" | tee -a "$OUT" >/dev/null
