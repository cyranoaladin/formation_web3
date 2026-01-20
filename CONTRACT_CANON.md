# Contrat canonique

## Objectif
- Définir les surfaces contractuelles et les attentes minimales (composants, endpoints, états, invariants) basées sur le dépôt actuel.

## Composants
- API (FastAPI)
- Worker (Python)
- UI (Vite/React) — port 3000
- RAG (présence du répertoire rag/)
- MongoDB

<!-- BEGIN:SYNC_ENDPOINTS -->

- GET /health
- POST /submissions/upload_zip
- GET /submissions/{submission_id}
- GET /runs/{run_id}
- GET /proofs/{proof_bundle_id}

<!-- END:SYNC_ENDPOINTS -->
## Endpoints
- /health
- /runs/{run_id}
- /submissions/upload_zip
- /submissions/{submission_id}

## Ports
- API: 8000
- UI: 3000

## États canoniques
- Submission.status: failed, needs_review, queued, running
- AutogradeRun.status: completed, queued, running
- ProofBundle.decision_hint: needs_review

## Invariants
- Chaque soumission possède un submission_id unique
- Chaque run possède un run_id unique
- Un run produit au plus un proof_bundle (lien run.proof_bundle_id)
- Les proof_bundles sont considérés immuables (pas de modification rétroactive)
