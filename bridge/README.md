# Bridge examples (simplified ASC bridge)

These tutorials implement a **simplified readability bridge** — not the production [write-ability](https://github.com/gluwa/usc-contracts/tree/main/contracts/write-ability) stack (Outbox, Relayer, Inbox, liquidity operators, etc.).

## What this example uses

| Piece                                            | Role                                                                                                                        |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| **`ASCBase`** (local)                            | Verify a source-chain transaction via the native verifier precompile (`0xFD2`), dedupe by `queryId`, delegate to app logic. |
| **`ASCMinter`** (local)                          | Decode a `TokensBurnedForBridging` log and mint wrapped tokens once per proof.                                              |
| **`EvmV1Decoder`** (from `@gluwa/usc-contracts`) | Shared library for decoding proved EVM receipts/logs (deploy via `contracts/decoding/`). Not the messaging bridge.          |
| **Tutorial scripts**                             | Build proofs and call `ASCMinter.execute(...)` directly. No relayer contract.                                               |

Flow: **burn on source chain → wait for attestation → fetch proof → `execute` on ASC → mint**.

Anyone with a valid proof can submit `execute`; the offchain worker is optional UX automation.

## What this example does not use

- Outbox / Relayer / Inbox messaging
- `ASCBridgeLiquidityOperator`, `ClientBridgeLiquidityOperator`, or other write-ability bridge contracts
- Trusted relayers or operator-gated mint paths

For the production bridge architecture, see [usc-contracts](https://github.com/gluwa/usc-contracts) and Creditcoin's write-ability documentation.

## Layout

```
bridge/
├── contracts/sol/     ASCBase, ASCMinter, MintableToken, BridgeTestToken
├── hello-bridge/      Pre-deployed ASC + burner (minimal setup)
├── custom-contracts-bridging/   Deploy your own ASC + wrapped token
└── bridge-offchain-worker/      Automate proof submission after burns
```

## Tutorials (recommended order)

1. [Hello Bridge](./hello-bridge/README.md)
2. [Custom Contracts Bridging](./custom-contracts-bridging/README.md)
3. [Bridge Offchain Worker](./bridge-offchain-worker/README.md)

Deployment troubleshooting: [contracts/CONTRIBUTING.md](./contracts/CONTRIBUTING.md).

## Before you run tutorials

```sh
yarn utils:check_setup hello   # after configuring .env for Hello Bridge
yarn utils:check_setup bridge  # after custom-contracts deploy
```

Deploy `EvmV1Decoder` **once** per Creditcoin network; set `EVM_V1_DECODER_LIBRARY_ADDRESS` in `.env` and reuse for loan deploys.

## Environment

Network and RPC settings live in the repository root [`.env`](../.env). Bridge-specific variable names are listed in [`.env.example`](./.env.example) as a convenience split.
