# Bridge Offchain Worker

Optional UX automation for the custom bridge: users only burn on Sepolia; the worker finishes the mint on Creditcoin so they do not run `yarn custom_bridge:submit_query` by hand. It is not required for security — anyone with a valid proof can still call `ASCMinter.execute` manually, but the ASC still only mints for source-chain emitters registered via `wrapOriginToken`.

**Flow:** poll Sepolia for `TokensBurnedForBridging` → wait for attestation and fetch a USC proof from the Proof Builder → submit that proof via `ASCMinter.execute` on CC3 Testnet → log `TokensMinted` on Creditcoin (requires the burn contract to already be registered with `wrapOriginToken`). Same burn → proof → mint path as the tutorial, without a write-ability Relayer.

> [!NOTE]
> **Start here:** [Custom Contract Bridging §7 — Automate proof submission](../custom-contracts-bridging/README.md#7-automate-proof-submission-optional) for the integrated tutorial step.

Implementation: `worker.ts`.

## Quick start

Prerequisites: complete [Custom Contract Bridging](../custom-contracts-bridging/README.md) (deployed `ASCMinter`, wrapped token, and `.env` vars).

```sh
source bridge/.env
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
