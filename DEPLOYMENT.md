# Déploiement

## Prérequis
- Docker installé
- Docker Compose installé
- (optionnel) `curl` pour tester

## Local (Docker Compose)
```bash
docker compose up -d --build
docker compose ps
```

Tests :
```bash
curl -sS http://localhost:8000/health
curl -sS http://localhost:3000/
```

## Local (dev hors Docker)
```bash
./start_dev.sh
```

- UI: `http://localhost:5173`
- API: `http://127.0.0.1:8000` (ou 8001 si 8000 est occupé)

## Note sur les volumes
- `docker-compose.override.yml` monte le repo en lecture seule dans `api` et `worker` (`/repo`).
- Cette montage est requis pour les schemas (`schemas/canonical`) et le runner (`runner/`).

## Rollback
```bash
docker compose down
```

Rollback simple = revenir au commit précédent et rebuild :
```bash
git checkout <commit>
docker compose up -d --build
```

## Production Deployment

For production environments, use the optimized `docker-compose.prod.yml` configuration. This setup leverages multi-stage builds for the frontend (served via Nginx) and removes development features like hot-reloading and source code volume mounts.

### Prerequisites

- Docker Engine & Docker Compose (v2+)
- A reverse proxy (e.g., Traefik, Nginx) handling SSL/TLS in front (recommended)

### Deployment Steps

1.  **Environment Configuration**:
    Create a `.env` file with production secrets:
    ```bash
    MONGODB_DB=rbk_labs_prod
    # Add other secrets here (e.g., external API keys)
    ```

2.  **Build and Start**:
    ```bash
    docker compose -f docker-compose.prod.yml up -d --build
    ```

3.  **Verification**:
    - Frontend: `http://localhost:3000` (or your domain)
    - API: `http://localhost:8000/health`

### Updates

To update the application:
1.  Pull new code: `git pull origin main`
2.  Rebuild and restart: `docker compose -f docker-compose.prod.yml up -d --build` (Zero-downtime is not guaranteed with this simple setup).

