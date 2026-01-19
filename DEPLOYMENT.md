# Déploiement

## Prerequisites
- Docker installé
- Docker Compose installé
- (optionnel) curl pour tester

## Local
commandes :
```bash
docker compose up -d --build
docker compose ps
```

tests :
```bash
curl -sS http://localhost:8000/health
curl -sS http://localhost:3000/  # optionnel (UI dev)
```

## Server
- Ouvrir les ports 8000 et 3000
- Se positionner dans le répertoire du dépôt

```bash
docker compose up -d --build
docker compose ps
```

## Rollback
```bash
docker compose down
docker image ls | head  # optionnel
```

- Rollback simple = revenir au commit précédent et rebuild :
```bash
git checkout <commit>
docker compose up -d --build
```
