<!-- CI badge placeholder: set remote to GitHub and replace OWNER/REPO -->
[![CI](https://github.com/cyranoaladin/formation_web3/actions/workflows/ci.yml/badge.svg)](https://github.com/cyranoaladin/formation_web3/actions/workflows/ci.yml)

# RBK Labs Platform – Solana Senior by Design

RBK Labs est une plateforme de formation Web3/Solana **senior-by-design** qui combine :

- des **labs audit-grade** (spécifications + scripts d'exécution)
- un **RAG pédagogique local** (index JSON, interrogé via API)
- un **autograder** (worker + runner minimal)
- une **UI terminal** (React/Vite) pour uploader et suivre les runs

➡️ Toute la documentation de ce repo est **normative**.
➡️ Rien n’est implicite.

## Objectifs
- Former des builders Solana capables de livrer du code production & audit-ready
- Standardiser l’évaluation par preuves (logs, diff, audit note, result.json)
- Fournir un RAG fiable, sourcé et versionné

## Périmètre actuel
- Track A : Solana (Rust, Anchor, Native)
- Labs présents : `hello-proof`, `security-02-unverified-pda`
- Exécution locale via Docker Compose ou `start_dev.sh`

## Démarrage rapide
Pré-requis : Docker + Docker Compose.

```bash
docker compose up -d --build
```

UI : http://localhost:3000
API : http://localhost:8000

Alternative (dev local, sans Docker Compose) :

```bash
./start_dev.sh
```

UI : http://localhost:5173 (Vite)
API : http://127.0.0.1:8000 (ou 8001 si 8000 est occupé)

## Architecture (résumé)
- **API** FastAPI (port 8000)
- **Worker** Python (poll + autograde)
- **Runner** minimal (`runner/minimal.py`) pour exécuter une commande de lab
- **UI** React/Vite (port 3000 en compose, 5173 en dev)
- **MongoDB** (état des submissions, runs, proof bundles)
- **RAG local** (`rag/db_local.json`) généré via `rag/ingest.py`

## Flux principal
`upload_zip` → `queued` → worker → `running` → `completed` (+ proof_bundle)

Cas particuliers :
- `needs_review` si validation schema échoue
- `failed` si erreur runtime

## Endpoints API
- `GET /health`
- `GET /labs`
- `POST /submissions/upload_zip`
- `GET /submissions/{submission_id}`
- `GET /runs/{run_id}`
- `GET /proofs/{proof_bundle_id}`
- `POST /rag/query`

## Data model (échantillons)
### Submission
```json
{
  "submission_id": "sub_0123456789abcdef0123456789abcdef",
  "student_id": "student_demo",
  "lab_id": "hello-proof",
  "status": "queued",
  "upload_path": "/tmp/rbk_uploads/upl_abcdef1234",
  "upload_sha256": "3b2c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5061728394a5b6c7d",
  "created_at": "2026-01-21T12:00:00Z",
  "updated_at": "2026-01-21T12:00:00Z"
}
```

### Autograde run
```json
{
  "run_id": "run_abcdef1234567890",
  "submission_id": "sub_0123456789abcdef0123456789abcdef",
  "status": "completed",
  "created_at": "2026-01-21T12:01:00Z",
  "updated_at": "2026-01-21T12:01:05Z",
  "result": {
    "ok": true,
    "decision_hint": "validated",
    "score_auto": 100,
    "files_count": 12
  },
  "proof_bundle_id": "proof_abcdef1234567890"
}
```

### Proof bundle
```json
{
  "proof_bundle_id": "proof_abcdef1234567890",
  "run_id": "run_abcdef1234567890",
  "submission_id": "sub_0123456789abcdef0123456789abcdef",
  "lab_id": "hello-proof",
  "created_at": "2026-01-21T12:01:05Z",
  "decision_hint": "validated",
  "score": {
    "auto": 100,
    "rubric": "placeholder"
  },
  "immutable": true,
  "artifacts": {
    "logs": "RBK Worker Logs (placeholder)\\n- upload_path: ...\\n- files_count: 12\\n",
    "tests": "RBK Tests (placeholder)\\n- not executed yet\\n",
    "diff": "[empty or content]",
    "audit": "[empty or content]",
    "result": {
      "status": "ok",
      "lab_id": "hello-proof",
      "submission_id": "sub_0123456789abcdef0123456789abcdef",
      "run_id": "run_abcdef1234567890",
      "started_at": "2026-01-21T12:01:00Z",
      "finished_at": "2026-01-21T12:01:05Z"
    }
  }
}
```

## Notes importantes
- Le runner est **minimal** et n’applique pas d’isolation forte (sandbox légère).
- Le RAG actuel est **local** (fichier JSON), sans embeddings externes.
- Les schemas canoniques sont dans `schemas/canonical/`.

Plus de détails : `ARCHITECTURE.md`, `SPEC.md`, `AUTOGRADING.md`, `RAG.md`.
