# Workflows repo local

Chaque workflow est un enchaînement d'étapes atomiques. Toujours fournir des preuves.

## preflight
- [ ] Vérifier outils de base (bash, curl)
- [ ] Vérifier présence des dossiers clés (`tools/steps`, `ui/`, `api/`, `worker/` si utilisés)
- [ ] Vérifier fichiers d'orchestration (ex: `docker-compose.yml`)
- Proof required: `tools/verify.sh --spec tools/verify.spec`

## build
- [ ] Construire les composants ciblés (ui, api, worker)
- [ ] Interdiction de compiler plusieurs cibles si non nécessaires
- Proof required: sorties de build minimales + empreintes fichiers générés

## smoke
- [ ] Lancer un service minimal et ping health
- [ ] Utiliser des ports par défaut documentés
- Proof required: `http_ok` sur endpoint(s) de santé

## doc-audit
- [ ] Énumérer README/CHANGELOG/ARCHITECTURE existants
- [ ] Détecter sections manquantes ou obsolètes
- Proof required: diff des sections détectées

## doc-fix
- [ ] Appliquer correctifs ciblés en patchs atomiques
- [ ] Éviter tout bruit éditorial
- Proof required: `sed -n` des lignes modifiées + hash

## verify
- [ ] Exécuter `tools/verify.sh --spec tools/verify.spec`
- [ ] Zéro FAIL autorisé
- Proof required: résumé PASS/FAIL et code de sortie 0