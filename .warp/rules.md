# Règles d'exécution Warp (repo local)

## Principes
- [x] Une seule étape à la fois, atomique
- [x] Exécution uniquement via des fichiers existants
- [x] Preuves obligatoires à la fin de l'étape
- [x] Ambiguïté => STOP et demande de décision

## Terminal et scripts
- [x] Pas de scripts en ligne > 5 lignes (aucun heredoc long, y compris Python)
- [x] Pas de mélange commande + sortie dans la même zone de saisie
- [x] Toujours utiliser `tools/run.sh tools/steps/<step>.sh`
- [x] Scripts d'étape sans commentaires narratifs; le nom et le code doivent suffire
- [x] N'exécuter que des chemins vérifiés (pas de suppositions)

## Portée des étapes
- [x] Une étape ne touche qu'un seul sous-système (api | worker | ui | rag | infra | docs)
- [x] Pas de "refactor + feature" dans la même étape
- [x] Pas d'effet de bord réseau non justifié

## Preuves (Proof required)
- [x] Définir les preuves attendues AVANT l'exécution
- [x] Types: `ls`, `sed -n`, hash, statuts précis, checks automatiques
- [x] Sans preuves conformes: interdiction d'enchaîner

## Sécurité
- [x] Aucune modification destructive sans étape dédiée + validation
- [x] Aucune écriture hors arborescence du dépôt
- [x] Pas d'accès secrets en clair; préférer variables d'environnement