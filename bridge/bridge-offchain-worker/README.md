# Bridge Offchain Worker

> [!NOTE]
> **Start here:** [Custom Contract Bridging §7 — Automate proof submission](../custom-contracts-bridging/README.md#7-automate-proof-submission-optional) for the integrated tutorial step.

This folder contains the worker implementation (`worker.ts`). It watches Sepolia for burns and calls `ASCMinter.execute` on CC3 Testnet — same simplified bridge as the manual `yarn custom_bridge:submit_query` path, with no write-ability Relayer.

## Quick start

Prerequisites: complete [Custom Contract Bridging](../custom-contracts-bridging/README.md) (deployed `ASCMinter`, wrapped token, and `.env` vars).

```sh
source .env
yarn offchain:start_worker
```

Burn on Sepolia in another terminal; the worker handles attestation, proof fetch, and mint.

## Required env vars

- `SOURCE_CHAIN_RPC_URL`, `SOURCE_CHAIN_CUSTOM_CONTRACT_ADDRESS`
- `ASC_CUSTOM_MINTER_CONTRACT_ADDRESS`, `ASC_CUSTOM_MINTABLE_TOKEN`
- `CREDITCOIN_RPC_URL`, `CREDITCOIN_WALLET_PRIVATE_KEY`, `SOURCE_CHAIN_KEY`, `PROOF_BUILDER_URL`

## Next

[Loan Flow](../../loan/scripts/README.md) — cross-chain loan state with a similar worker pattern.

[Custom Contract Bridging]: ../custom-contracts-bridging/README.md
[Loan Flow]: ../../loan/scripts/README.md
