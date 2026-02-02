use anchor_lang::prelude::*;

declare_id!("5ST4AajQCmR2YKurdqDM1BWwAZJRc98JbfzyHCA3i1Ak");

#[program]
pub mod security_02_unverified_pda {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, points: u64) -> Result<()> {
        let user_stats = &mut ctx.accounts.user_stats;
        user_stats.points = points;
        user_stats.bump = *ctx.bumps.get("user_stats").unwrap();
        Ok(())
    }

    // Helper pour l'attaquant: cree un compte UserStats SANS les seeds forcees
    pub fn create_fake_user_stats(ctx: Context<CreateFake>, points: u64) -> Result<()> {
        let user_stats = &mut ctx.accounts.user_stats;
        user_stats.points = points;
        user_stats.bump = 0;
        Ok(())
    }

    pub fn set_points(ctx: Context<SetPoints>, points: u64) -> Result<()> {
        let user_stats = &mut ctx.accounts.user_stats;
        user_stats.points = points;
        Ok(())
    }

    pub fn claim_reward(ctx: Context<ClaimReward>) -> Result<()> {
        let user_stats = &ctx.accounts.user_stats;

        if user_stats.points <= 100 {
            return Err(ErrorCode::NotEnoughPoints.into());
        }

        let amount: u64 = 1_000_000;
        let vault = &mut ctx.accounts.vault;

        require!(vault.to_account_info().lamports() >= amount, ErrorCode::VaultEmpty);

        **vault.to_account_info().try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.user.to_account_info().try_borrow_mut_lamports()? += amount;

        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = user,
        space = 8 + 8 + 1,
        seeds = [b"stats", user.key().as_ref()],
        bump
    )]
    pub user_stats: Account<'info, UserStats>,
    #[account(
        init_if_needed,
        payer = user,
        seeds = [b"vault"],
        bump,
        space = 8
    )]
    pub vault: Account<'info, Vault>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CreateFake<'info> {
    #[account(init, payer = user, space = 8 + 8 + 1)]
    pub user_stats: Account<'info, UserStats>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct SetPoints<'info> {
    #[account(
        mut,
        seeds = [b"stats", user.key().as_ref()],
        bump = user_stats.bump
    )]
    pub user_stats: Account<'info, UserStats>,
    pub user: Signer<'info>,
}

#[derive(Accounts)]
pub struct ClaimReward<'info> {
    #[account(mut)]
    pub user: Signer<'info>,

    #[account(
        mut,
        seeds = [b"stats", user.key().as_ref()],
        bump = user_stats.bump
    )]
    pub user_stats: Account<'info, UserStats>,

    #[account(mut, seeds = [b"vault"], bump)]
    pub vault: Account<'info, Vault>,

    pub system_program: Program<'info, System>,
}

#[account]
pub struct UserStats {
    pub points: u64,
    pub bump: u8,
}

#[account]
pub struct Vault {}

#[error_code]
pub enum ErrorCode {
    #[msg("Not enough points")]
    NotEnoughPoints,
    #[msg("Vault empty")]
    VaultEmpty,
}
