# RAG – Retrieval Augmented Generation
## Objectif
Fournir des réponses :
- Exactes
- Sourcées
- Alignées sur le contenu RBK
- Versionnées
## Backend
- Embeddings : OpenAI / BGE / autre
- Vector Store : MongoDB Atlas Vector Search
## Objets indexés
- content_items
- content_chunks
- labs specs
- rubrics
- snapshots docs
## Règles
- Un chunk = une idée atomique
- Toute réponse cite ses sources
- Jamais d’invention hors base canonique
## Endpoint
POST /rag/query
→ réponse + citations + score