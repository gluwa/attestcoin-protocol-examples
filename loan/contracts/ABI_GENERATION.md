# ABI Generation

After changing loan contracts under `loan/contracts/sol/`, regenerate ABIs from the repository root:

```sh
yarn
./loan/contracts/abi-creator.sh
```

Loan contracts import readability `ASCBase` and `EvmV1Decoder` from `@gluwa/asc-contracts` (same base as the bridge examples). Shared source-chain `TestERC20` lives under `shared/contracts/`. ABI regeneration: see [bridge/contracts/CONTRIBUTOR_NOTES.md](../../bridge/contracts/CONTRIBUTOR_NOTES.md) and `./shared/contracts/abi-creator.sh`.
