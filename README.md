# 🌉 ASC Testnet Bridge Examples 🌉

This repository is a starting point for exploring Creditcoin cross-chain **readability** (Attestcoin Smart Contracts). The **bridge** tutorials use a **simplified ASC bridge** — local `ASCMinter` on shared package `ASCBase`, direct `execute` calls — **not** the full write-ability production stack (Outbox / Relayer / Inbox). See [bridge/README.md](./bridge/README.md).

`@gluwa/usc-contracts` is installed from GitHub [`gluwa/asc-contracts`](https://github.com/gluwa/asc-contracts) `main` (`git+https://github.com/gluwa/asc-contracts.git#main`). CI authenticates with secret `ASC_CONTRACTS_READ_TOKEN` (see [CI setup](#ci-private-asc-contracts)).

Learn how to use the Creditcoin Decentralized Oracle through guided tutorials where you set up and interact with your own decentralized bridge and loan examples.

## Repository layout

```
usc-testnet-bridge-examples/
├── bridge/                 # Simplified ASC bridge tutorials + ASCMinter (ASCBase from @gluwa/usc-contracts)
│   ├── contracts/          # Example ASC apps; ASCBase + EvmV1Decoder from @gluwa/usc-contracts
│   ├── hello-bridge/
│   ├── custom-contracts-bridging/
│   └── bridge-offchain-worker/
├── loan/                   # Cross-chain loan tutorial + loan contracts
│   ├── contracts/          # ASCLoanManager, AuxiliaryLoanContract, …
│   └── scripts/            # Loan flow CLI scripts
├── shared/
│   ├── contracts/          # TestERC20 (shared Sepolia burner for bridge + loan)
│   └── utils/              # Proof builder + submit helpers shared by both examples
```

Package overview: [bridge/README.md](./bridge/README.md) (simplified bridge model and what is out of scope).

## Before you start

Before attempting any of the tutorials, make sure the following are installed:

- [yarn]
- [foundry]

Install dependencies from the repository root (needs read access to private `gluwa/asc-contracts`):

```sh
# Optional if HTTPS clone of gluwa/asc-contracts fails without auth:
#   git config --global url."https://x-access-token:${ASC_CONTRACTS_READ_TOKEN}@github.com/".insteadOf "https://github.com/"
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
yarn utils:check_setup loan    # after loan stack deploy
```

Deploy `EvmV1Decoder` once per Creditcoin network; save `EVM_V1_DECODER_LIBRARY_ADDRESS` in `.env` and reuse for the loan tutorial.

Full verification checklist: [VERIFICATION.md](./VERIFICATION.md).

### CI: private `asc-contracts`

GitHub Actions cannot fetch `gluwa/asc-contracts` anonymously. Add a repo/org secret:

1. Create a fine-grained PAT (or GitHub App token) with **Contents: Read** on `gluwa/asc-contracts`.
2. Add secret **`ASC_CONTRACTS_READ_TOKEN`** on this repository (Settings → Secrets and variables → Actions).
3. Workflows run `.github/actions/install-js-deps`, which checkouts [`gluwa/asc-contracts`](https://github.com/gluwa/asc-contracts) `main` with that token into `vendor/asc-contracts`, then `yarn install` via `file:vendor/asc-contracts` (avoids yarn’s unauthenticated git fetch on private repos).

Fork PRs will not receive this secret unless you use a trusted workflow pattern.
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
