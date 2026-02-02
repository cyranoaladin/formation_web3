# Warp — README (repo local)

Ce dépôt utilise Warp en mode exécution strict. Objectif: cadence fiable, traçable, reproductible.

## ADN d'exécution
- [x] 1 étape à la fois (atomique, mono-responsabilité)
- [x] Preuves obligatoires après chaque étape
- [x] Scripts d'étape sous `tools/steps/` exécutés via `tools/run.sh`
- [x] Pas de "scénarios" longs dans le terminal
- [x] STOP après preuves, attendre validation humaine

## Comment opérer
- Écrire une étape: `tools/steps/stepNN_<verbe>_<cible>.sh`
- Lancer: `tools/run.sh tools/steps/stepNN_*.sh`
- Les étapes ne doivent pas modifier plusieurs sous-systèmes en même temps.
- Ambiguïté détectée => arrêter immédiatement et demander une décision.

## Ce que Warp NE fait pas
- Pas de commandes collées à la volée > 5 lignes
- Pas de mélange commandes/sorties dans un même collage
- Pas de devinettes sur les chemins; toujours vérifier avant d'agir
- Pas d'édition manuelle sans fichier support

## Preuves (Proof required)
- Chaque step définit ses preuves: listings, checks, sorties ciblées
- Les preuves sont factuelles, brèves, vérifiables
- En absence de preuves: interdiction d'enchaîner

## Journalisation
- Tous les runs écrivent sous `tools/logs/`
- Conserver les logs pour audit et rollback

## Cycle recommandé
1. preflight
2. build
3. smoke
4. doc-audit
5. doc-fix
6. verify

Respecter ce cadre pour garder vitesse ET qualité. Toute exception nécessite accord explicite et preuves renforcées.
