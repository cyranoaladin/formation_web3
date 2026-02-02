# Contrat canonique

## Objectif
Définir les surfaces contractuelles et attentes minimales (composants, endpoints, états, invariants) basées sur le dépôt actuel.

## Composants
- API (FastAPI)
- Worker (Python)
- Runner minimal (`runner/minimal.py`)
- UI (Vite/React)
- RAG local (`rag/db_local.json`)
- MongoDB

## Endpoints (synchronised)
<!-- BEGIN:SYNC_ENDPOINTS -->

- GET /health
- GET /labs
- POST /submissions/upload_zip
- GET /submissions/{submission_id}
- GET /runs/{run_id}
- GET /proofs/{proof_bundle_id}
- POST /rag/query

<!-- END:SYNC_ENDPOINTS -->

## Ports
- API: 8000
- UI: 3000 (compose) / 5173 (dev)

## États canoniques (observés)
- `Submission.status`: `queued`, `running`, `completed`, `needs_review`, `failed`
- `AutogradeRun.status`: `running`, `completed`, `failed`
- `ProofBundle.decision_hint`: `needs_review`, `validated`, `failed`

## Invariants
- Chaque soumission possède un `submission_id` unique
- Chaque run possède un `run_id` unique
- Un run produit au plus un proof_bundle (`run.proof_bundle_id`)
- Les proof_bundles sont immuables (pas de modification rétroactive)

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
