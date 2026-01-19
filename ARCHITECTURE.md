# Architecture Technique

## Vue d’ensemble
### Schéma logique
UI → API → Mongo
           ↓
        Worker → Docker Runner
           ↓
         Proofs → Mongo
           ↓
           RAG

### Principes
- API stateless
- Worker scalable
- Index RAG séparé
- Données “source of truth” immuables

## Composants
- API : FastAPI (port 8000)
- Worker : file queued → run/proof_bundle
- UI : Vite + React (port 3000)
- Données : Local : Mongo (container mongo:7); Prod (optionnel) : MongoDB Atlas / Atlas Vector Search (pour RAG)

## Orchestration
- docker-compose.yml orchestre api, worker, ui, mongo

## Ports
- API: 8000
- UI: 3000

## Flux
- upload_zip → queued → worker → run → proof_bundle

## Endpoints
GET /health
POST /submissions/upload_zip
POST /rag/query
