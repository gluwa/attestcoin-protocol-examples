# Bridge contracts — contributor notes

Tutorial users can skip this file. It covers ABI regeneration and deployment troubleshooting for maintainers.

## Regenerate ABIs

After changing contracts under `bridge/contracts/sol/`:

```sh
yarn
./bridge/contracts/abi-creator.sh
```

For loan contracts: `./loan/contracts/abi-creator.sh`.

Bridge contracts are local simplified readability contracts (`ASCBase`, `ASCMinter`). Only `EvmV1Decoder` is imported from `@gluwa/usc-contracts`.

## Deploy troubleshooting

Common `forge create` issues when deploying `ASCMinter` with a linked `EvmV1Decoder` library:

### Nonce / "already known"

- Wait 10–30s and retry `ASCMinter` deploy (decoder address unchanged).
- Or raise gas: `--gas-price <higher>`.
- Or set explicit nonce: `cast nonce <address> --rpc-url $CREDITCOIN_RPC_URL` then `--nonce`.

### Insufficient funds

Fund the deployer on Creditcoin testnet (Discord faucet). Check balance:

```bash
cast balance <your_address> --rpc-url $CREDITCOIN_RPC_URL
```

### Hangs on confirmation

`forge create` waits for inclusion; slow RPCs can take 1–5 minutes. Check the explorer if unsure.

### Library link errors

Ensure `--libraries` uses the deployed decoder address:

```bash
--libraries node_modules/@gluwa/usc-contracts/contracts/decoding/EvmV1Decoder.sol:EvmV1Decoder:<decoder_library_address>
```

The library is published in npm at `contracts/decoding/EvmV1Decoder.sol`. Tutorials and Solidity imports both use that path via `@gluwa/usc-contracts` from `node_modules`.

After deploy, submit proofs with `yarn hello_bridge:submit_query` or `yarn custom_bridge:submit_query`.
