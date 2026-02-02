# Autograding

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

## Objectif
L’autograder évalue une soumission, produit un run et un proof_bundle, puis met à jour le statut.

## Entrées
- Soumission: archive ZIP via `POST /submissions/upload_zip` (form-data: `student_id`, `lab_id`, `file`)
- Identifiants renvoyés: `submission_id`, `upload_id` (statut initial: `queued`)

## Sorties
- `run_id`
- `proof_bundle_id`
- `decision_hint` (par défaut `needs_review`, `validated` pour `hello-proof` si runner OK)
- `score.auto` (placeholder: 50 ou 100)

## Composants
- **API** : FastAPI (upload + consultation)
- **Worker** : boucle de traitement `queued → running → completed|needs_review|failed`
- **Runner** : `runner/minimal.py` (exécute la commande du lab)
- **MongoDB** : persistance des submissions, runs, proof_bundles

## Exécution locale
```bash
docker compose up -d --build
```

## Vérification (preuves)
- Santé API :
```bash
curl -sS http://localhost:8000/health
```
- Démo E2E (smoke) :
```bash
bash tools/run.sh tools/steps/003_smoke_e2e.sh
```

## Notes / limites
- Le runner est **minimal** et ne fournit pas d’isolation forte.
- Les tests/autograde sont encore placeholders (artefacts générés, pas d’évaluation complète).
