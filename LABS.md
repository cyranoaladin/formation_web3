# Labs

## Objectif
- Les labs sont des unités d’évaluation exécutables, évaluées par l’autograding.
- Les exécutions produisent un run et un proof_bundle (preuves) associés aux soumissions.

## Inventaire des labs
- labs/rubrics/
- labs/specs/

## Structure d’un lab
- spec (YAML/JSON si présent)
- assets (si présents)
- scripts d’exécution (si présents)
- sorties attendues: proof_bundle (logs/tests/diff/audit)

## Cycle d’exécution
- upload_zip → queued → worker → run → proof_bundle

## Vérification (preuves)
```bash
bash tools/verify.sh --spec tools/verify.spec
```

## Limites actuelles
- Runner en mode placeholder (isolement fort non garanti)
