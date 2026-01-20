# Spécification Fonctionnelle – RBK Labs

## Acteurs
- Student
- Mentor
- Admin
- Autograder Worker
- RAG Engine

## Cas d’usage clés
1. Soumettre un lab (ZIP)
2. Exécuter un runner isolé (Docker)
3. Générer des preuves (tests.json, patch.diff, audit_note.md)
4. Calculer un score automatique
5. Entrer en état `needs_review`
6. Revue mentor
7. Progression compétences
8. Interrogation RAG avec citations

## États d’une soumission
- uploaded
- running
- failed
- needs_review
- reviewed
- validated

## Exigences non fonctionnelles
- Reproductibilité
- Isolation
- Versionnement
- Observabilité
- Auditabilité

## Objectif
- Spécification fonctionnelle minimale du dépôt

## Parcours utilisateur
- Parcours principal: upload_zip → queued → worker → run → proof_bundle

## Objets et données
- submissions
- runs
- proof_bundle

## États canoniques
- queued
- needs_review
- completed

## Critères d’acceptation
- API répond 200 sur /health
- Upload zip crée une submission en queued
- Worker produit un run et un proof_bundle

<!-- BEGIN:SYNC_ENDPOINTS -->

- GET /health
- POST /submissions/upload_zip
- GET /submissions/{submission_id}
- GET /runs/{run_id}
- GET /proofs/{proof_bundle_id}

<!-- END:SYNC_ENDPOINTS -->
## Endpoints
GET /health
POST /submissions/upload_zip

