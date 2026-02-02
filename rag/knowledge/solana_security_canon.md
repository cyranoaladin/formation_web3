# CHECK-01: Owner Validation

Toujours verifier que le compte passe appartient au bon proprietaire logique.
L'erreur classique: accepter un compte arbitraire et ne pas verifier son champ owner.

Exemple (verification manuelle):

```rust
require_keys_eq!(vault.owner, authority.key(), ErrorCode::Unauthorized);
```

Ou via contrainte Anchor:

```rust
#[account(constraint = vault.owner == authority.key())]
```

# CHECK-02: PDA Verification

Un PDA doit etre verifie par ses seeds et son bump. Sans ces contraintes,
le client peut passer un compte arbitraire (fake PDA).

Exemple (seeds + bump):

```rust
#[account(
    mut,
    seeds = [b"stats", user.key().as_ref()],
    bump = user_stats.bump
)]
pub user_stats: Account<'info, UserStats>;
```

# CHECK-03: Signer vs Authority

Signer signifie "a signe la transaction". Authority signifie "a le droit".
Un compte peut signer sans etre l'autorite attendue.
Il faut comparer la cle stockee dans l'etat.

Exemple:

```rust
require_keys_eq!(vault.authority, authority.key(), ErrorCode::Unauthorized);
```

Ou avec Anchor:

```rust
#[account(has_one = authority)]
pub vault: Account<'info, Vault>;
```
