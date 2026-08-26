# ABI Generation

After changing loan contracts under `loan/contracts/sol/`, regenerate ABIs from the repository root:

```sh
yarn
./loan/contracts/abi-creator.sh
```

Loan contracts import `ASCBase` and decoding libraries from `@gluwa/usc-contracts` (see `loan/foundry.toml` remappings).
