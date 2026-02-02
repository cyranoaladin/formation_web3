# Architecture Technique

## Vue d’ensemble (logique)
UI → API → MongoDB
         ↓
      Worker → runnerd → runner-base (Docker sandbox)
         ↓
    Proof Bundles → MongoDB
         ↓
         RAG local

## Principes
- API stateless
- Worker polling (queue Mongo)
- Proof bundles immuables une fois écrits
- RAG local versionné (fichier JSON généré)

## Composants
- **API** : FastAPI (port 8000)
- **Worker** : Python (poll + autograde)
- **Runnerd** : service HTTP (port 9000) qui orchestre l’exécution sandbox
- **Runner-base** : image Docker exécutant `/runner/entrypoint.py` et produisant les artefacts bruts
- **UI** : Vite + React (port 3000 en compose, 5173 en dev)
- **MongoDB** : `mongo:7`
- **RAG** : base locale `rag/db_local.json` (générée via `rag/ingest.py`)

## Orchestration
- `docker-compose.yml` orchestre api, worker, ui, mongo
- `docker-compose.override.yml` monte le repo en lecture seule dans api/worker (`/repo`)

## Ports
- API: 8000
- UI: 3000 (compose) / 5173 (start_dev)

## Flux
- `POST /submissions/upload_zip` → status `queued`
- Worker: `queued` → `running` → `completed` + `proof_bundle`
- `needs_review` si validation schema échoue
- `failed` si erreur runtime

## Artefacts runner
- runner-base écrit `out/result.raw.json` et `out/logs.jsonl`
- runnerd écrit `out/result.json` final (source-of-truth) et `out/system.jsonl` (événements runnerd)

## Endpoints
- `GET /health`
- `GET /labs`
- `POST /submissions/upload_zip`
- `GET /submissions/{submission_id}`
- `GET /runs/{run_id}`
- `GET /proofs/{proof_bundle_id}`
- `POST /rag/query`
