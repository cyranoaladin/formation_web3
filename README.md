<!-- CI badge placeholder: set remote to GitHub and replace OWNER/REPO -->
[![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/ci.yml)

# RBK Labs Platform – Solana Senior by Design

RBK Labs est une plateforme de formation Web3/Solana de niveau **senior-by-design**, combinant :

- Une **plateforme de labs audit-grade**
- Un **RAG pédagogique canonique**
- Un **système d’auto-correction et de revue mentor**
- Des **dashboards étudiant / mentor**
- Une **culture de preuve (tests, audits, invariants)**

## Objectifs
- Former des builders Solana **capables de livrer du code production & audit-ready**
- Standardiser l’évaluation par preuves (tests, patchs, notes d’audit)
- Fournir un RAG fiable, sourcé, versionné, traçable

## Public cible
- Étudiants avancés / reconversion senior
- Formateurs techniques
- Mentors / reviewers / auditeurs

## Périmètre
- Track A : Solana (Rust, Anchor, Native)
- Durée 48 semaines
- Niveau de sortie : Senior / Audit-Ready / Infra-Aware

➡️ Toute la documentation de ce repo est **normative**.
➡️ Rien n’est implicite.

## Architecture
- Orchestration: docker-compose.yml
- Ports: API 8000 (/health), UI 3000
- Flux: upload_zip → queued → worker → run/proof_bundle

## Installation
prérequis: Docker + Docker Compose


## Run
docker compose up -d --build

docker compose ps


## Ports
API: 8000

UI: 3000


## Endpoints
GET /health (API)

POST /submissions/upload_zip (API)

POST /rag/query (API)

## API
- Service HTTP sur 8000
- Endpoint santé: GET /health
- Déclaré dans docker-compose.yml

## Worker
- Traite la file queued
- Exécute run/proof_bundle sur archives upload_zip

## UI
- Service sur port 3000 (développement)
- Accessible en navigateur local

## RAG
- Présence d'un pipeline RAG (cf. RAG.md)
