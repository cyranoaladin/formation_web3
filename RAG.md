# RAG – Retrieval Augmented Generation

## Objectif
Fournir des réponses :
- Exactes
- Sourcées
- Alignées sur le contenu RBK
- Versionnées

## Implémentation actuelle
- **Index local** : `rag/db_local.json`
- **Ingestion** : `rag/ingest.py` (canon + INSTRUCTIONS des labs)
- **API** : `POST /rag/query`

## Objets indexés
- Canon de sécurité (`rag/knowledge/solana_security_canon.md`)
- INSTRUCTIONS des labs (`labs/specs/*/INSTRUCTIONS.md`)

## Réponse API
- `system_prompt` : prompt d’aide (avec contexte intégré)
- `chunks` : extraits sourcés + score

## Règles
- Un chunk = une idée atomique
- Toute réponse cite ses sources (via `chunks`)
- Pas d’invention hors base canonique

## Notes
- Pas d’embeddings externes ni de vector store pour le moment.
- La sélection est un scoring lexical simple.
