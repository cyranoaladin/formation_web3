# Compétences opérationnelles (skills)

## docker-compose
- [ ] Construire/démarrer/arrêter des services de façon sûre
- [ ] Jamais de volumes destructifs sans confirmation
- Proof required: `docker compose ps`, `config`, hashes

## fastapi
- [ ] Démarrer l'API, exposer `/health`
- [ ] Logs lisibles, erreurs explicites
- Proof required: `http_ok http://localhost:8000/health`

## vite (UI)
- [ ] Démarrer le dev server proprement
- [ ] Scripts `package.json` cohérents
- Proof required: `http_ok http://localhost:3000/`

## mongo
- [ ] Démarrer et vérifier disponibilité
- [ ] Connexion/collection de test optionnelles
- Proof required: logs + ping/connexions réussies

## scripts safe
- [ ] Étapes sous `tools/steps/` uniquement
- [ ] Pas de heredoc > 5 lignes
- Proof required: permissions + listings

## édition markdown
- [ ] Édits ciblés, sections bien délimitées
- [ ] Pas d'URL mortes, pas de références externes opaques
- Proof required: `sed -n` des blocs modifiés