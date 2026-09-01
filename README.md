# 🌉 Attestcoin Protocol Examples 🌉

This repository is a starting point for exploring cross-chain inter-operability using the Attestcoin protocol. Today, it contains several examples covering Attestcoin readability. Coming soon: examples using Attestcoin writability!

By running through the tutorials in this repository, you will set up and interact with your own decentralized bridge and loan examples.

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
[Loan Flow]: ./loan/README.md
[ASC Architecture Overview]: https://docs.attestcoin.org/attestcoin-protocol/architecture
[DApp Builder Infrastructure]: https://docs.attestcoin.org/attestcoin-protocol/dapp-builder-infrastructure
[Attestcoin Readability Subsystems]: https://docs.attestcoin.org/attestcoin-protocol/attestcoin-readability
