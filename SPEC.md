# Spécification Fonctionnelle – RBK Labs

## Acteurs
- Student
- Mentor
- Admin
- Autograder Worker
- RAG Engine (local)

## Cas d’usage clés
1. Soumettre un lab (ZIP)
2. Exécuter un runner minimal (commande du lab)
3. Générer des preuves (logs/tests/diff/audit/result)
4. Calculer un score automatique (placeholder)
5. Consulter l’état et les artefacts
6. Interroger le RAG avec contexte de lab

## États d’une soumission (observés en code)
- `queued`
- `running`
- `completed`
- `needs_review` (validation schema échoue)
- `failed` (erreur runtime)

## Exigences non fonctionnelles
- Reproductibilité
- Isolation minimale (sandbox runner)
- Versionnement
- Observabilité
- Auditabilité

## Parcours utilisateur
`upload_zip` → `queued` → worker → `running` → `completed` (+ `proof_bundle`)

## Objets et données
- `submissions`
- `autograde_runs`
- `proof_bundles`
- `labs` (indexés depuis `labs/specs/*/lab.json`)
- `rag` (fichier JSON local)

## Critères d’acceptation (actuels)
- API répond 200 sur `/health`
- Upload ZIP crée une submission `queued`
- Worker produit un `run` et un `proof_bundle`
- RAG renvoie un `system_prompt` + `chunks`

## Data model (échantillons)
### Submission
```json
{
  "submission_id": "sub_0123456789abcdef0123456789abcdef",
  "student_id": "student_demo",
  "lab_id": "hello-proof",
  "status": "queued",
  "upload_path": "/tmp/rbk_uploads/upl_abcdef1234",
  "upload_sha256": "3b2c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5061728394a5b6c7d",
  "created_at": "2026-01-21T12:00:00Z",
  "updated_at": "2026-01-21T12:00:00Z"
}
```

### Autograde run
```json
{
  "run_id": "run_abcdef1234567890",
  "submission_id": "sub_0123456789abcdef0123456789abcdef",
  "status": "completed",
  "created_at": "2026-01-21T12:01:00Z",
  "updated_at": "2026-01-21T12:01:05Z",
  "result": {
    "ok": true,
    "decision_hint": "validated",
    "score_auto": 100,
    "files_count": 12
  },
  "proof_bundle_id": "proof_abcdef1234567890"
}
```

### Proof bundle
```json
{
  "proof_bundle_id": "proof_abcdef1234567890",
  "run_id": "run_abcdef1234567890",
  "submission_id": "sub_0123456789abcdef0123456789abcdef",
  "lab_id": "hello-proof",
  "created_at": "2026-01-21T12:01:05Z",
  "decision_hint": "validated",
  "score": {
    "auto": 100,
    "rubric": "placeholder"
  },
  "immutable": true,
  "artifacts": {
    "logs": "RBK Worker Logs (placeholder)\\n- upload_path: ...\\n- files_count: 12\\n",
    "tests": "RBK Tests (placeholder)\\n- not executed yet\\n",
    "diff": "[empty or content]",
    "audit": "[empty or content]",
    "result": "{\\\"status\\\":\\\"ok\\\",\\\"lab_id\\\":\\\"hello-proof\\\"}"
  }
}
```

## Endpoints (synchronised)
<!-- BEGIN:SYNC_ENDPOINTS -->

- GET /health
- GET /labs
- POST /submissions/upload_zip
- GET /submissions/{submission_id}
- GET /runs/{run_id}
- GET /proofs/{proof_bundle_id}
- POST /rag/query

<!-- END:SYNC_ENDPOINTS -->

## Notes
- Les schemas canoniques sont dans `schemas/canonical/`.
- Le runner exécute la commande définie dans `lab.json` (si présente).
