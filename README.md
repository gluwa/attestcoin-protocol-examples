# 🌉 ASC Testnet Bridge Examples 🌉

This repository is a starting point for exploring Creditcoin cross-chain **readability** (Attestcoin Smart Contracts). The **bridge** tutorials use a **simplified ASC bridge** — local `ASCBase` + `ASCMinter`, direct `execute` calls — **not** the full write-ability production stack (Outbox / Relayer / Inbox). See [bridge/README.md](./bridge/README.md).

Learn how to use the Creditcoin Decentralized Oracle through guided tutorials where you set up and interact with your own decentralized bridge and loan examples.

## Repository layout

```
usc-testnet-bridge-examples/
├── bridge/                 # Simplified ASC bridge tutorials + contracts (ASCBase, ASCMinter)
│   ├── contracts/          # Local readability contracts; EvmV1Decoder lib from @gluwa/usc-contracts
│   ├── hello-bridge/
│   ├── custom-contracts-bridging/
│   └── bridge-offchain-worker/
├── loan/                   # Cross-chain loan tutorial + loan contracts
│   ├── contracts/          # ASCLoanManager, AuxiliaryLoanContract, TestERC20, …
│   └── scripts/            # Loan flow CLI scripts
└── shared/utils/           # Proof builder + submit helpers shared by both examples
```

Package overview: [bridge/README.md](./bridge/README.md) (simplified bridge model and what is out of scope).

## Before you start

Before attempting any of the tutorials, make sure the following are installed:

- [yarn]
- [foundry]

Install dependencies from the repository root:

```sh
yarn
```

Set up Foundry:

```bash
foundryup --version v1.2.3
```

Copy and fill in environment files for the examples you plan to run. `.env` holds your wallet
private key, so it is git-ignored and never committed — `.env.example` is the tracked copy, which
carries only public network defaults:

- Bridge tutorials: `bridge/.env.example` → `bridge/.env` (or root `.env`)
- Loan tutorial: `loan/.env.example` → `loan/.env` (or root `.env`)

> [!CAUTION]
> Keep your private key in `.env` only. Never put it in `.env.example`, which is tracked by git.

Then source your env file and verify connectivity:

```bash
source .env
yarn utils:check_setup hello   # Hello Bridge
yarn utils:check_setup bridge  # after custom-contracts deploy
```

Deploy `EvmV1Decoder` once per Creditcoin network; save `EVM_V1_DECODER_LIBRARY_ADDRESS` in `.env` and reuse for the loan tutorial.

Full verification checklist: [VERIFICATION.md](./VERIFICATION.md).

## Tutorials

We recommend going through them in this order:

1. 📚 [Hello Bridge] — pre-deployed contracts, manual proof submit
2. 📚 [Custom Contracts Bridging] — deploy your ASC + optional worker (§7)
3. 📚 [Bridge Offchain Worker] — short reference (main flow in custom-contracts §7)
4. 📚 [Loan Flow] — reuses decoder library from bridge

## External Resources

- 📚 [ASC Architecture Overview]
- 📚 [DApp Builder Infrastructure]
- 📚 [Attestcoin Readability Subsystems]

[yarn]: https://yarnpkg.com/getting-started/install
[foundry]: https://getfoundry.sh/
[Hello Bridge]: ./bridge/hello-bridge/README.md
[Custom Contracts Bridging]: ./bridge/custom-contracts-bridging/README.md
[Bridge Offchain Worker]: ./bridge/bridge-offchain-worker/README.md
[Loan Flow]: ./loan/scripts/README.md
[ASC Architecture Overview]: https://docs.attestcoin.org/attestcoin-protocol/architecture
[DApp Builder Infrastructure]: https://docs.attestcoin.org/attestcoin-protocol/dapp-builder-infrastructure
[Attestcoin Readability Subsystems]: https://docs.attestcoin.org/attestcoin-protocol/attestcoin-readability
