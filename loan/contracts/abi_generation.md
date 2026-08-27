# ABI Generation

After changing loan contracts under `loan/contracts/sol/`, regenerate ABIs from the repository root:

```sh
yarn
./loan/contracts/abi-creator.sh
```

Loan contracts import readability `ASCBase` and `EvmV1Decoder` from `@gluwa/usc-contracts`. ABI regeneration: see [bridge/contracts/CONTRIBUTING.md](../../bridge/contracts/CONTRIBUTING.md).
