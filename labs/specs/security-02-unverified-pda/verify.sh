#!/usr/bin/env bash
set -euo pipefail

npm install --silent

solana-test-validator --reset --quiet &
VALIDATOR_PID=$!
trap "kill $VALIDATOR_PID" EXIT
sleep 5

solana config set --url http://localhost:8899 >/dev/null

mkdir -p .anchor
solana-keygen new --no-bip39-passphrase --force -o .anchor/wallet.json >/dev/null
solana config set --keypair .anchor/wallet.json >/dev/null
export ANCHOR_WALLET="$(pwd)/.anchor/wallet.json"

for i in 1 2 3 4 5; do
  solana airdrop 10 || true
  BAL=$(solana balance | awk '{print $1}')
  if awk "BEGIN {exit !($BAL >= 5.0)}"; then
    break
  fi
  sleep 2
  if [ "$i" -eq 5 ]; then
    echo "Airdrop failed; balance=$BAL"
    exit 1
  fi
done

mkdir -p target/deploy
cp -f keys/security_02_unverified_pda-keypair.json target/deploy/security_02_unverified_pda-keypair.json

anchor build
anchor test --skip-local-validator

echo "SUCCESS"
