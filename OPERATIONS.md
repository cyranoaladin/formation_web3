# Exploitation

## Monitoring
- latence RAG
- échecs autograde
- saturation workers

## Maintenance
- rebuild index RAG
- update Solana toolchain
- migration lab specs

## Incidents
- rollback runner
- désactivation lab

## Runbook
- Vérifier l’état global :
  docker compose ps
- Vérifier la santé API :
  curl -sS http://localhost:8000/health
- Redémarrage ciblé :
  docker compose restart api
  docker compose restart worker
- Redémarrage complet :
  docker compose down
  docker compose up -d --build
## Logs
- Logs globaux :
  docker compose logs --tail=100
- Logs par service :
  docker compose logs api
  docker compose logs worker
  docker compose logs ui
