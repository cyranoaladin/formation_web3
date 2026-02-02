# Security N1 — Unverified PDA (Fake Seeds)

## Contexte
Le programme gère un compte `UserStats` censé être un **PDA** dérivé de l’utilisateur :
`[b"stats", user.key()]`.

L’instruction `claim_reward` vérifie `user_stats.points > 100` pour payer une récompense.

## Problème
Le programme **ne vérifie pas** que `user_stats` est bien le PDA attendu.
Un attaquant peut créer un **faux compte** avec 9999 points et le passer à l’instruction.

## Mission
Corriger `ClaimReward` en ajoutant la contrainte de PDA dans le contexte :

- `seeds = [b"stats", user.key().as_ref()]`
- `bump = user_stats.bump`

Une fois patché, le test d’attaque doit échouer (Constraint Error).

## Rappels
- Test A : utilisateur légitime avec 10 points → échec attendu.
- Test A suite : 101 points → succès attendu.
- Test B : faux compte → doit échouer après patch.
