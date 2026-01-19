# Autograding

## Objectif
- L’autograder RBK évalue une soumission, produit un run et un proof_bundle, et met à jour le statut.

## Entrées
- Soumission: archive ZIP via POST /submissions/upload_zip (form-data: student_id, lab_id, file)
- Identifiants renvoyés: submission_id, upload_id (statut initial: queued)

## Sorties
- proof_bundle_id (créé par le worker)
- score_auto (placeholder)
- decision_hint (ex: needs_review)
- run_id (run d’autograde lié à la soumission)

## Composants
- API (FastAPI) : endpoints confirmés: /health, /runs/{run_id}, /submissions/upload_zip, /submissions/{submission_id}
- Worker (Python) : boucle de traitement queued -> running -> needs_review/failed + création run et proof_bundle
- Runner : placeholder (aucune exécution isolée confirmée)
- MongoDB : persistance des submissions, runs et proof_bundles

## Exécution locale (reproductible)
```bash
docker compose up -d --build
docker compose ps
```

## Vérification (preuves)
- Santé API :
```bash
curl -sS http://localhost:8000/health
```
- Démo de bout en bout (smoke) :
```bash
bash tools/run.sh tools/steps/003_smoke_e2e.sh
```

## Notes / limites
- Le runner est actuellement un placeholder (runner.kind="placeholder"); les tests sont simulés.
- Le score_auto renvoyé par le worker est un exemple (50) et sert de valeur de démonstration.
