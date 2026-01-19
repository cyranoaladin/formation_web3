# Spec de vérification minimale pour ce repo
# Les lignes vides et celles commençant par # sont ignorées.
# Conserver uniquement des checks très fiables.

PATH docker-compose.yml
PATH tools/steps
CONTAINS docker-compose.yml ^services:
PATH .warp
PATH .warp/README.md
CONTAINS .warp/README.md Warp
