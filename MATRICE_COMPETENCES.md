# Matrice de compétences

## Principes
- Compétences observables (liées à des artefacts/commandes du dépôt)
- Preuves exigées (logs, proof_bundle, endpoints fonctionnels)
- Progression par paliers (Junior → Intermediate → Senior)

## Niveaux
- Junior
- Intermediate
- Senior

## Domaines
- Architecture
- API
- Worker / Autograding
- RAG
- DevOps / Exécution
- Documentation & preuves

## Matrice
### Junior — Architecture
- compétence: Identifier les composants présents (API, Worker, UI, Mongo, Runner, RAG local)
- preuve attendue: lecture `docker-compose.yml` + `ARCHITECTURE.md`

### Intermediate — Architecture
- compétence: Tracer le flux `upload_zip → queued → running → completed`
- preuve attendue: logs worker ou lecture `worker/worker.py`

### Senior — Architecture
- compétence: Vérifier invariants (IDs uniques, run → proof_bundle)
- preuve attendue: lecture `CONTRACT_CANON.md` + code `worker/worker.py`

### Junior — API
- compétence: Tester la santé de l’API
- preuve attendue: `curl -sS http://localhost:8000/health`

### Intermediate — API
- compétence: Décrire les endpoints exposés
- preuve attendue: `/health`, `/labs`, `/submissions/*`, `/runs/*`, `/proofs/*`, `/rag/query`

### Senior — API
- compétence: Diagnostiquer un échec d’upload_zip (statuts/erreurs)
- preuve attendue: lecture `api/app/main.py` + reproduction contrôlée

### Junior — Worker / Autograding
- compétence: Expliquer les statuts `queued/running/completed`
- preuve attendue: lecture `worker/worker.py`

### Intermediate — Worker / Autograding
- compétence: Produire un run et observer proof_bundle
- preuve attendue: `bash tools/run.sh tools/steps/003_smoke_e2e.sh`

### Senior — Worker / Autograding
- compétence: Qualifier le runner et les artefacts
- preuve attendue: `runner/minimal.py` + logs `/tmp/rbk_runner/<submission_id>`

### Junior — RAG
- compétence: Identifier l’index local et ses sources
- preuve attendue: `rag/db_local.json` + `rag/ingest.py`

### Intermediate — RAG
- compétence: Interroger `/rag/query`
- preuve attendue: payload JSON + réponse `system_prompt`/`chunks`

### Senior — RAG
- compétence: Proposer un pipeline d’embeddings (non implémenté)
- preuve attendue: plan technique + contraintes

### Junior — DevOps / Exécution
- compétence: Lancer l’environnement local
- preuve attendue: `docker compose up -d --build`

### Intermediate — DevOps / Exécution
- compétence: Vérifier la santé globale
- preuve attendue: `bash tools/verify.sh --spec tools/verify.spec`

### Senior — DevOps / Exécution
- compétence: Collecter des logs ciblés pour diagnostic
- preuve attendue: `docker compose logs --tail=100 worker`

### Junior — Documentation & preuves
- compétence: Ajouter une section factuelle dans un .md
- preuve attendue: diff clair + références au code

### Intermediate — Documentation & preuves
- compétence: Écrire un step atomique idempotent sous `tools/steps/`
- preuve attendue: `bash tools/run.sh tools/steps/<step>.sh`

### Senior — Documentation & preuves
- compétence: Définir des critères de validation et s'arrêter après preuves
- preuve attendue: logs + verify PASS
