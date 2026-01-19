# Matrice de compétences

## Principes
- Compétences observables (liées à des artefacts/commandes du dépôt)
- Preuves exigées (logs, proof_bundle, endpoints fonctionnels, verify PASS)
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

## Matrice (listes structurées)
### Junior — Architecture
- compétence: Comprendre les composants présents (API, Worker, UI, Mongo) et les ports exposés
- preuve attendue: docker compose ps (si présent) ; lecture docker-compose.yml

### Intermediate — Architecture
- compétence: Tracer le flux upload_zip → queued → run → proof_bundle
- preuve attendue: exécution de smoke (si disponible) ou lecture des logs worker

### Senior — Architecture
- compétence: Valider les invariants CONTRACT_CANON (IDs uniques, 1 run → ≤1 proof_bundle)
- preuve attendue: preuve par lecture des documents et/ou sortie de 003_smoke_e2e.sh

### Junior — API
- compétence: Tester la santé de l’API
- preuve attendue: curl -sS http://localhost:8000/health

### Intermediate — API
- compétence: Décrire les endpoints détectés
- preuve attendue: /health, /runs/{run_id}, /submissions/upload_zip, /submissions/{submission_id}

### Senior — API
- compétence: Diagnostiquer un échec d’upload_zip (statuts/erreurs)
- preuve attendue: lecture api/app/main.py + reproduction contrôlée

### Junior — Worker / Autograding
- compétence: Expliquer les statuts queued/running/needs_review
- preuve attendue: lecture worker/worker.py

### Intermediate — Worker / Autograding
- compétence: Produire un run et observer proof_bundle
- preuve attendue: bash tools/run.sh tools/steps/003_smoke_e2e.sh

### Senior — Worker / Autograding
- compétence: Qualifier le runner et les artefacts de preuve
- preuve attendue: runner.kind=placeholder

### Junior — RAG
- compétence: Identifier la présence du répertoire rag/ et l’état des fonctionnalités
- preuve attendue: ls -la rag/

### Intermediate — RAG
- compétence: Cartographier ce qui est documenté dans RAG.md
- preuve attendue: lecture RAG.md (aucun endpoint confirmé dans le code API)

### Senior — RAG
- compétence: Aligner RAG avec les invariants (sans promesse d’endpoint)
- preuve attendue: revue croisée docs ↔ code

### Junior — DevOps / Exécution
- compétence: Lancer l’environnement local
- preuve attendue: docker compose up -d --build

### Intermediate — DevOps / Exécution
- compétence: Vérifier les invariants minimaux
- preuve attendue: bash tools/verify.sh --spec tools/verify.spec

### Senior — DevOps / Exécution
- compétence: Collecter des logs ciblés pour diagnostic
- preuve attendue: docker compose logs --tail=100 worker

### Junior — Documentation & preuves
- compétence: Ajouter une section minimale factuelle dans un .md
- preuve attendue: grep structure + sha256 avant/après

### Intermediate — Documentation & preuves
- compétence: Écrire un step atomique idempotent sous tools/steps/
- preuve attendue: bash tools/run.sh tools/steps/<step>.sh + preuves

### Senior — Documentation & preuves
- compétence: Définir des critères de validation et arrêter après preuves
- preuve attendue: verify PASS + logs de step

