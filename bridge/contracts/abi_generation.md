# ABI Generation

After changing bridge contracts under `bridge/contracts/sol/`, regenerate ABIs from the repository root:

```sh
yarn
./bridge/contracts/abi-creator.sh
```

For loan contracts, use `./loan/contracts/abi-creator.sh` instead.
