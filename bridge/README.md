# Bridge examples (simplified ASC bridge)

These tutorials implement a **simplified readability bridge** — not the production write-ability stack (Outbox, Relayer, Inbox, liquidity operators, etc.) published as [`@gluwa/usc-contracts`](https://www.npmjs.com/package/@gluwa/usc-contracts).

This example follows **[Attestcoin Readability — Building a Bridge Minter (§6.4)](https://docs.attestcoin.org/attestcoin-protocol/attestcoin-readability)** (inherit `ASCBase`, prove a source-chain burn, mint wrapped tokens on Creditcoin).

## What this example uses

| Piece                                            | Role                                                                                                                                        |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **`ASCBase`** (from `@gluwa/usc-contracts`)      | Shared readability base: verify via native precompile (`0xFD2`), dedupe by `queryId`, delegate to app logic. Same base as the loan example. |
| **`ASCMinter`** (local)                          | Decode a `TokensBurnedForBridging` log and mint wrapped tokens **only if the source-chain emitter is whitelisted** via `wrapOriginToken`.   |
| **`EvmV1Decoder`** (from `@gluwa/usc-contracts`) | Shared library for decoding proved EVM receipts/logs (deploy via `contracts/common/`). Not the messaging bridge.                            |
| **Tutorial scripts**                             | Build proofs and call `ASCMinter.execute(...)` directly. No relayer contract.                                                               |

Flow: **burn on source chain → wait for attestation → fetch proof → `execute` on ASC → mint** (mint requires the burn contract address to be a whitelisted emitter).

Anyone with a valid proof can submit `execute`, but the ASC still rejects burns from emitters that were never registered; the offchain worker is optional UX automation.

## What this example does not use

- Outbox / Relayer / Inbox messaging
- `ASCBridgeLiquidityOperator`, `ClientBridgeLiquidityOperator`, or other write-ability bridge contracts
- Trusted relayers or operator-gated mint paths

For the production bridge architecture, see [`@gluwa/usc-contracts`](https://www.npmjs.com/package/@gluwa/usc-contracts) and Creditcoin's write-ability documentation.

## Layout

```
bridge/
├── contracts/sol/     ASCMinter, MintableToken, BridgeTestToken (ASCBase from package)
├── hello-bridge/      Pre-deployed ASC + burner (minimal setup)
├── custom-contracts-bridging/   Deploy your own ASC + wrapped token
└── bridge-offchain-worker/      Automate proof submission after burns
```

## Tutorials (recommended order)

1. [Hello Bridge](./hello-bridge/README.md)
2. [Custom Contracts Bridging](./custom-contracts-bridging/README.md)
3. [Bridge Offchain Worker](./bridge-offchain-worker/README.md)

Deployment troubleshooting: [contracts/Contributor Notes.md](./contracts/Contributor%20Notes.md).

## Before you run tutorials

```sh
yarn utils:check_setup hello   # after configuring .env for Hello Bridge
yarn utils:check_setup bridge  # after custom-contracts deploy
```

Deploy `EvmV1Decoder` **once** per Creditcoin network; set `EVM_V1_DECODER_LIBRARY_ADDRESS` in `.env` and reuse for loan deploys.

## Environment

Network and RPC settings live in the repository root [`.env`](../.env). Bridge-specific variable names are listed in [`.env.example`](./.env.example) as a convenience split.
