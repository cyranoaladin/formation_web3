import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Keypair, SystemProgram } from "@solana/web3.js";
import BN from "bn.js";
import { expect } from "chai";

describe("security-02-unverified-pda", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.Security02UnverifiedPda as Program;

  const getVaultPda = () =>
    anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("vault")],
      program.programId
    )[0];

  it("Test A (legit): points check works, then reward succeeds", async () => {
    const user = provider.wallet.publicKey;

    const [userStatsPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("stats"), user.toBuffer()],
      program.programId
    );

    const vaultPda = getVaultPda();

    await program.methods
      .initialize(new BN(10))
      .accounts({
        userStats: userStatsPda,
        vault: vaultPda,
        user,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    const fundTx = new anchor.web3.Transaction().add(
      SystemProgram.transfer({
        fromPubkey: user,
        toPubkey: vaultPda,
        lamports: 1_000_000_000,
      })
    );
    await provider.sendAndConfirm(fundTx, []);

    let failed = false;
    try {
      await program.methods
        .claimReward()
        .accounts({
          user,
          userStats: userStatsPda,
          vault: vaultPda,
          systemProgram: SystemProgram.programId,
        })
        .rpc();
    } catch (e) {
      failed = true;
    }
    if (!failed) throw new Error("Claim should fail with low points");

    await program.methods
      .setPoints(new BN(101))
      .accounts({
        userStats: userStatsPda,
        user,
      })
      .rpc();

    const before = await provider.connection.getBalance(user);

    await program.methods
      .claimReward()
      .accounts({
        user,
        userStats: userStatsPda,
        vault: vaultPda,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    const after = await provider.connection.getBalance(user);
    expect(after).to.be.greaterThan(before);
  });

  it("Test B (exploit): fake PDA should be rejected after patch", async () => {
    const attacker = Keypair.generate();
    const sig = await provider.connection.requestAirdrop(
      attacker.publicKey,
      2_000_000_000
    );
    await provider.connection.confirmTransaction(sig, "confirmed");

    const vaultPda = getVaultPda();

    await program.methods
      .initialize(new BN(1))
      .accounts({
        userStats: anchor.web3.PublicKey.findProgramAddressSync(
          [Buffer.from("stats"), attacker.publicKey.toBuffer()],
          program.programId
        )[0],
        vault: vaultPda,
        user: attacker.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([attacker])
      .rpc();

    const fundTx = new anchor.web3.Transaction().add(
      SystemProgram.transfer({
        fromPubkey: attacker.publicKey,
        toPubkey: vaultPda,
        lamports: 1_000_000_000,
      })
    );
    await provider.sendAndConfirm(fundTx, [attacker]);

    const fakeStats = Keypair.generate();

    await program.methods
      .createFakeUserStats(new BN(9999))
      .accounts({
        userStats: fakeStats.publicKey,
        user: attacker.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([attacker, fakeStats])
      .rpc();

    let failed = false;
    try {
      await program.methods
        .claimReward()
        .accounts({
          user: attacker.publicKey,
          userStats: fakeStats.publicKey,
          vault: vaultPda,
          systemProgram: SystemProgram.programId,
        })
        .signers([attacker])
        .rpc();
    } catch (e) {
      failed = true;
    }

    if (!failed) {
      throw new Error("Exploit succeeded: unverified PDA accepted");
    }
  });
});
