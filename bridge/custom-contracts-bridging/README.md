# Custom Contract Bridging

> [!NOTE]
> Deploys the **simplified** local `ASCMinter` / `ASCBase` pair — direct `execute` minting, no relayer contracts. See [bridge/README.md](../README.md).

> [!TIP]
> This tutorial builds on the previous [Hello Bridge] example -make sure to check it out before
> moving on!

Now that you have performed your first _trustless bridge transaction_, let's keep going with the next
step: this tutorial teaches you how to set up your own custom bridging logic by deploying your own
smart contracts!

## 0. Install

For our tutorial scripts to function properly, we need to install dependencies first.

```bash
yarn install
```

## 1. Setup

This is the same as in [Hello Bridge]. If you have not already done so, follow the installation
steps in the [setup] section there before continuing.

## 2. Deploy A Test `ERC20` Contract on Sepolia

Let's start by deploying our own `ERC20` contract on Sepolia. The contract contains logic for
tracking the balances of a coin called `TEST`. The contract also automatically funds its creator's
address with 1,000,000 `TEST` coins, so we won't have to mint `TEST` tokens manually.

Make sure to first load your `.env` file with:

```sh
source .env
```

After, run the following command to deploy the contract:

```sh
forge create \
    --broadcast \
    --rpc-url $SOURCE_CHAIN_RPC_URL \
    --private-key $CREDITCOIN_WALLET_PRIVATE_KEY \
    loan/contracts/sol/TestERC20.sol:TestERC20
```

This should display some output containing the address of your test `ERC20` contract:

```bash
Deployer: 0x20dB67795C2AEb4De075986b0D4217A109FEF2B5
Deployed to: 0xCDf3e9eC93015a1B3047d087296C1cE096f33f74
Transaction hash: 0xfb0aaf396684bf0727019e5271d7e0dedee1dea9e5a4a1ef7456662d0ac07b12
```

Save the contract address shown in `Deployed to:`. You will be needing it in the next step.

Additionally update the `.env` file at the root of the repository with the address, like so:

```env
SOURCE_CHAIN_CUSTOM_CONTRACT_ADDRESS=<test_erc20_contract_address_from_step_2>
```

Once again, reload your `.env` file with:

```sh
source .env
```

## 3. Deploy your bridging stack

You will deploy the stock `ASCMinter` from this repo — **no contract edits required** for the default path.

### 3.1 Deploy `EvmV1Decoder` (once per Creditcoin network)

Deploy the shared decoding library. **Save this address** — you can reuse it for the [Loan Flow](../../loan/scripts/README.md) without deploying again.

```bash
forge create \
  --broadcast \
  --rpc-url $CREDITCOIN_RPC_URL \
  --private-key $CREDITCOIN_WALLET_PRIVATE_KEY \
  node_modules/@gluwa/usc-contracts/contracts/decoding/EvmV1Decoder.sol:EvmV1Decoder
```

Add the library address to your root `.env` so later steps (and the loan tutorial) can reuse it:

```env
EVM_V1_DECODER_LIBRARY_ADDRESS=<decoder_library_address>
```

Reload:

```sh
source .env
```

> **Note:** Deploy from `contracts/decoding/EvmV1Decoder.sol` in the npm package. That library is a shared receipt decoder — not the Outbox/Relayer bridge stack.

### 3.2 Deploy `ASCMinter`

```bash
forge create \
    --broadcast \
    --rpc-url $CREDITCOIN_RPC_URL \
    --private-key $CREDITCOIN_WALLET_PRIVATE_KEY \
    --libraries node_modules/@gluwa/usc-contracts/contracts/decoding/EvmV1Decoder.sol:EvmV1Decoder:$EVM_V1_DECODER_LIBRARY_ADDRESS \
    bridge/contracts/sol/ASCMinter.sol:ASCMinter
```

If deployment fails (nonce, gas, etc.), see [Contributor deploy notes](../contracts/CONTRIBUTING.md).

You should get output with the contract address:

```bash
Deployer: 0x20dB67795C2AEb4De075986b0D4217A109FEF2B5
Deployed to: 0xCDf3e9eC93015a1B3047d087296C1cE096f33f74
Transaction hash: 0xe86e3c2f77fd050a4120dbd195668af2f3d94f3a41b5db21643c53c1ac3cc212
```

### 3.3 Update environment with your ASC contract address

Save the address and update the root `.env`:

```env
ASC_CUSTOM_MINTER_CONTRACT_ADDRESS=<asc_address_from_step_3_2>
```

Reload:

```sh
source .env
```

### 3.4 Deploy wrapped token and register the route

Deploy the wrapped ERC20 owned by your minter:

```bash
forge create \
    --broadcast \
    --rpc-url $CREDITCOIN_RPC_URL \
    --private-key $CREDITCOIN_WALLET_PRIVATE_KEY \
    bridge/contracts/sol/BridgeTestToken.sol:BridgeTestToken \
    --constructor-args "$ASC_CUSTOM_MINTER_CONTRACT_ADDRESS"
```

Update `.env`:

```env
ASC_CUSTOM_MINTABLE_TOKEN=<ERC20_address_from_step_3_4>
```

Register the Sepolia source token → wrapped token mapping:

```bash
cast send \
    --rpc-url $CREDITCOIN_RPC_URL \
    $ASC_CUSTOM_MINTER_CONTRACT_ADDRESS \
    "wrapOriginToken(address, address)" $SOURCE_CHAIN_CUSTOM_CONTRACT_ADDRESS $ASC_CUSTOM_MINTABLE_TOKEN \
    --private-key $CREDITCOIN_WALLET_PRIVATE_KEY
```

Optional preflight before burning:

```sh
yarn utils:check_setup bridge
```

## 4. Burning the tokens you want to bridge

The following few steps are similar to what we did in the [Hello Bridge] example. Start by burning
the tokens you want to bridge on the _source chain_ (Sepolia in this case). We will be burning the
`TEST` tokens from the test `ERC20` contract which we deployed in [step 2]. We do this by
transferring them to an address for which the private key is unknown, making them inaccessible.

Run the following command to initiate the burn:

```bash
cast send \
    --rpc-url $SOURCE_CHAIN_RPC_URL \
    $SOURCE_CHAIN_CUSTOM_CONTRACT_ADDRESS \
    "burn(uint256)" 50000000000000000000 \
    --private-key $CREDITCOIN_WALLET_PRIVATE_KEY
```

This should display some output stating that your transaction was a success, along with a
transaction hash:

```bash
transactionHash         0xbc1aefc42f7bc5897e7693e815831729dc401877df182b137ab3bf06edeaf0e1
```

Save the transaction hash. You will be needing it in the next step.

## 5. Submit a mint query to the ASC contract

Now that we've burnt funds on Sepolia, we can use that transaction to request a mint in our custom ASC contract,
this also includes generating the proof for the Oracle using the Creditcoin proof generator library.

```sh
yarn custom_bridge:submit_query <transaction_hash_from_step_4>
```

On a succesfull query, you should see some messages like the following from the script:

```sh
Transaction 0xfd432f2c8ff1930ba5527e85c15fdaf68894f52ee6c975d61a745a6d55577341 found in block 11073177
Waiting for block 11073177 attestation on Creditcoin...
Latest attested height for chain key 1: 11073130
Height 11073177 not yet attested and in proof builder service cache for chain key 1. Latest height: 11073130. Retrying in 15000ms...
Height 11073177 not yet attested and in proof builder service cache for chain key 1. Latest height: 11073130. Retrying in 15000ms...
...
Height 11073177 not yet attested and in proof builder service cache for chain key 1. Latest height: 11073170. Retrying in 15000ms...
Block 11073177 attested! Generating proof...
Proof generation successful!
⏳ Estimating gas...
   Estimated gas: 419719, Gas limit with buffer: 566620
Proof submitted:  0xe9960fab9592311b7abc2097216828b64c6f6791ba47151714cd619705415ec3
Waiting for transaction to be mined...
Tokens minted! Contract: 0xD1A5c57654636146417B589aED99C56b9c73C510, To: 0x20dB67795C2AEb4De075986b0D4217A109FEF2B5, Amount: 50000000000000000000, QueryId: 0x3a18d51bb0433b512a770dd1e6bfbbec534f5ad76acdd657d1764141c5fba494
```

Sometimes it may take a bit more for the `TokensMinted` event to trigger, but should be no more than 30 seconds.

Once that's done we only need to check our newly minted tokens!

## 6. Verify Your Bridged Tokens

As a final check, verify that your tokens were successfully minted on Creditcoin Testnet. You can check your balance using:

```bash
WALLET_ADDRESS=$(cast wallet address --private-key $CREDITCOIN_WALLET_PRIVATE_KEY)
yarn utils:check_balance $ASC_CUSTOM_MINTABLE_TOKEN $WALLET_ADDRESS
```

This will return your balance in whole (BTKT) token units. With the default `ASCMinter`, the minted amount should **match** the amount you burned on Sepolia.

It should show something like this:

```bash
🔗 Using RPC URL: https://rpc.cc3-testnet.creditcoin.network
📦 Token: Bridge Test Token (BTKT)
🧾 Raw Balance: 50000000000000000000
💰 Formatted Balance: 50.0 BTKT
Decimals for token micro unit: 18
```

## 7. Automate proof submission (optional)

The same burn → proof → `execute` flow can run automatically so users only sign the **burn** on Sepolia. Start the worker (requires steps 2–3 complete):

```sh
yarn offchain:start_worker
```

In another terminal, burn tokens — the worker submits the mint proof when attestation completes:

```sh
cast send --rpc-url $SOURCE_CHAIN_RPC_URL \
    $SOURCE_CHAIN_CUSTOM_CONTRACT_ADDRESS \
    "burn(uint256)" 2000 \
    --private-key $CREDITCOIN_WALLET_PRIVATE_KEY
```

The worker is **UX-only** — anyone can still call `execute` manually with `yarn custom_bridge:submit_query`. Full worker walkthrough: [bridge-offchain-worker/README.md](../bridge-offchain-worker/README.md).

## Optional challenge: mint 2× burned amount

To experiment with customizing ASC logic, edit `bridge/contracts/sol/ASCMinter.sol` so `_processMint` mints `burntValue * 2`, redeploy the minter (reusing the same `EVM_V1_DECODER_LIBRARY_ADDRESS`), and repeat the burn + submit flow. This dilutes token supply and is for learning only.

## Conclusion

Congratulations! You've deployed your own simplified ASC bridge (`ASCMinter` + wrapped token) and completed a trustless mint.

Next: [Loan Flow](../../loan/scripts/README.md) reuses your decoder library and extends the pattern with cross-chain loan state.

[Hello Bridge]: ../hello-bridge/README.md
[setup]: ../hello-bridge/README.md#1-setup
[step 2]: #2-deploy-a-test-erc20-contract-on-sepolia
[step 3.2]: #32-deploy-ascminter
[step 5]: #5-submit-a-mint-query-to-the-asc-contract
[Contributor deploy notes]: ../contracts/CONTRIBUTING.md
[Bridge Offchain Worker]: ../bridge-offchain-worker/README.md
