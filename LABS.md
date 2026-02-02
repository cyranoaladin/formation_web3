# Labs

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
Les labs sont des unités d’évaluation exécutables, évaluées par l’autograding.
Chaque exécution produit un `run` et un `proof_bundle` associés à la soumission.

## Inventaire actuel
- `labs/specs/hello-proof`
- `labs/specs/security-02-unverified-pda`

## Index des labs (API)
- `GET /labs` retourne l’index construit depuis `labs/specs/*/lab.json`

## Structure d’un lab
- `lab.json` (métadonnées + commande d’exécution)
- `INSTRUCTIONS.md` (optionnel, utilisé par le RAG)
- scripts / assets propres au lab

## Cycle d’exécution
`upload_zip` → `queued` → worker → `running` → `completed` → `proof_bundle`

## Vérification (preuves)
```bash
bash tools/verify.sh --spec tools/verify.spec
```

## Limites actuelles
- Runner minimal, pas d’isolation forte
