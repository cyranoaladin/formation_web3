# Contributing

## Scope
- Ce dépôt RBK Labs accepte des contributions sur la documentation, les scripts et le code.

## Workflow (atomic steps + proofs)
- Chaque changement est implémenté via un step atomique sous tools/steps/.
- Exécuter un step avec le runner et STOP après preuves:
```bash
bash tools/run.sh tools/steps/<step>.sh
```

## Local verification
- Vérifier localement avant toute PR:
```bash
bash tools/verify.sh --spec tools/verify.spec
docker compose up -d --build
curl -sS http://localhost:8000/health
```

## Branches
- Utilisez des branches courtes: feat/<topic>, fix/<topic>, docs/<topic>, chore/<topic>.

## Commits
- Message clair, court, à l’impératif. Pas de convention imposée.
- La ligne Co-Authored-By est optionnelle (si pertinent).

## Pull request
- Checklist minimale:
  - verify PASS
  - preuves incluses (extraits de logs, greps)
  - pas de changements hors scope
