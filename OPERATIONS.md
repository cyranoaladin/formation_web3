# Exploitation

## Monitoring (actuel)
- Erreurs d’upload_zip (API)
- Erreurs worker (logs)
- Disponibilité Mongo
- Latence perçue RAG (API)

## Maintenance
- Rebuild index RAG : `python rag/ingest.py`
- Mise à jour des labs : modifier `labs/specs/*`
- Rebuild services : `docker compose up -d --build`

## Incidents
- Worker bloqué : vérifier logs + `WORKER_STALE_MIN` (requeue)
- Runner KO : vérifier `runner/minimal.py` et logs dans `/tmp/rbk_runner/<submission_id>`

## Runbook
- État global :
  - `docker compose ps`
- Santé API :
  - `curl -sS http://localhost:8000/health`
- Logs ciblés :
  - `docker compose logs --tail=100 api`
  - `docker compose logs --tail=100 worker`
  - `docker compose logs --tail=100 ui`
- Redémarrage ciblé :
  - `docker compose restart api`
  - `docker compose restart worker`
- Redémarrage complet :
  - `docker compose down`
  - `docker compose up -d --build`

## Mode dev hors Docker
- Lancer `./start_dev.sh` (API + worker + UI)
- UI sur `http://localhost:5173`
