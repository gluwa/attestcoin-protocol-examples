# ABI Generation

After changing loan contracts under `loan/contracts/sol/`, regenerate ABIs from the repository root:

```sh
yarn
./loan/contracts/abi-creator.sh
```

Loan contracts import readability `ASCBase` and `EvmV1Decoder` from `@gluwa/usc-contracts` (same base as the bridge examples). Shared source-chain `TestERC20` lives under `shared/contracts/`. ABI regeneration: see [bridge/contracts/Contributor Notes.md](../../bridge/contracts/Contributor%20Notes.md) and `./shared/contracts/abi-creator.sh`.
