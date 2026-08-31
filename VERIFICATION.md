# Verification checklist

Use this to validate the repository locally before release or deployment.

## Automated (CI + local)

From the repository root (requires [Foundry](https://getfoundry.sh/) on your `PATH`). Bridge and loan both inherit readability `ASCBase` and `EvmV1Decoder` from `@gluwa/asc-contracts` (`contracts/readability/`, `contracts/common/`):

```sh
yarn
git clone --depth 1 https://github.com/foundry-rs/forge-std lib/forge-std   # once
yarn verify
```

This runs:

| Step       | Command          | What it checks                                                                           |
| ---------- | ---------------- | ---------------------------------------------------------------------------------------- |
| TypeScript | `yarn typecheck` | Tutorial scripts compile                                                                 |
| Lint       | `yarn eslint`    | TS/JS style                                                                              |
| Contracts  | `yarn build`     | `forge build` for bridge + loan                                                          |
| Unit tests | `forge test`     | Loan source-contract binding; bridge burn-log parsing + emitter whitelist / query dedupe |

### CI (`solidity.yml`)

- Compiles bridge and loan contracts
- Regenerates ABIs and fails on drift
- Runs `forge test` for bridge and loan (requires `yarn install` + `forge-std`)

## Network preflight (optional, needs `.env`)

Does **not** submit transactions. Verifies RPC, proof builder, native verifier precompile (`0xFD2`), and chain-key attestation:

```sh
source .env
yarn utils:check_setup network   # RPC + attestation only
yarn utils:check_setup hello     # + hello-bridge contract addresses
yarn utils:check_setup bridge    # + wallet key for custom bridge
yarn utils:check_setup loan      # + loan contracts and lender/borrower keys
```

## Manual end-to-end — Hello Bridge

- [ ] `yarn utils:check_setup hello` passes
- [ ] Mint test tokens on Sepolia (`cast send … mint`)
- [ ] Burn tokens (`cast send … burn`) — save tx hash
- [ ] `yarn hello_bridge:submit_query <tx_hash>` — expect `Proof generation successful!` then `Tokens minted!`
- [ ] `yarn utils:check_balance $ASC_MINTABLE_TOKEN $WALLET` — balance matches burn amount

Expected mint output (abbreviated):

```text
Block <N> attested! Generating proof...
Proof generation successful!
Proof submitted:  0x...
Tokens minted! Contract: 0x..., To: 0x..., Amount: 50000000000000000000, QueryId: 0x...
```

## Manual end-to-end — Custom bridge + loan

- [ ] Deploy `EvmV1Decoder` once; set `EVM_V1_DECODER_LIBRARY_ADDRESS`
- [ ] Deploy `ASCMinter`, wrapped token, `wrapOriginToken` (whitelists the Sepolia burn emitter)
- [ ] Burn → `yarn custom_bridge:submit_query` → mint succeeds once
- [ ] Second submit with same proof reverts (`Query already processed`)
- [ ] Proof of a burn from a non-whitelisted emitter reverts (`Emitter not whitelisted`) — also covered by `forge test --root bridge` (`ASCMinterSecurity.t.sol`)
- [ ] Deploy loan stack; `yarn loan_flow:register_source_contract`
- [ ] Fund/repay on Sepolia; worker or manual proof updates loan status
- [ ] Spoofed `LoanFunded` from unregistered contract cannot mark loan funded (covered by unit tests)

## Loan source-contract binding (unit tests)

`forge test --root loan` must pass:

- `testFundLog_rejectsUnregisteredSource`
- `testFundLog_rejectsWrongEmitter`
- `testRepayLog_rejectsWrongEmitter`
- `testFundLog_acceptsRegisteredEmitter`
- `testRepayLog_acceptsRegisteredEmitter`

These assert fund/repay proofs must come from the registered `sourceLoanContract` address.
