# Sécurité Plateforme

## Menaces principales
- ZIP path traversal
- ZIP bomb / exhaustion disque
- Exécution de commandes non sûres dans le runner
- Absence d’isolation forte (runner minimal)

## Contremesures implémentées
- Extraction ZIP sécurisée (vérification chemins + limites) dans l’API
- Limites tailles ZIP/unzipped et nombre de fichiers
- Extension whitelist pour les fichiers uploadés
- Validation schema JSON des objets canon (soumissions, runs, proofs)

## Gaps connus
- Les quotas CPU/RAM/timeout et l’isolation forte doivent être appliqués de manière déterministe dans la chaîne runnerd → runner-base
- Les artefacts de preuve doivent être matérialisés dans le workspace (pas de preuve via stdout/stderr runnerd)
- Pas de signature/immutabilité cryptographique des preuves

## Recommandations futures
- Exécuter les labs dans un conteneur isolé (namespace/uid non root)
- Ajouter des quotas (CPU/RAM/durée) par lab
- Signer et hasher les artefacts de preuve
