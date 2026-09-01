import { ethers } from 'ethers';

import { chainInfo } from '@gluwa/usc-sdk';
import { isValidContractAddress, isValidPrivateKey } from './utils';
import { loadEnv } from './env';

const VERIFIER_PRECOMPILE = '0x0000000000000000000000000000000000000FD2';

type SetupMode = 'hello' | 'hello-bridge' | 'bridge' | 'custom' | 'loan' | 'network';

/** Loads the same files the tutorial scripts do, so a passing check reflects what they will see. */
function loadTutorialEnv(mode: SetupMode): void {
  if (mode === 'loan') {
    loadEnv('loan');
  } else if (mode === 'network') {
    loadEnv();
  } else {
    loadEnv('bridge');
  }
}

function normalizeMode(raw: string | undefined): SetupMode {
  const mode = (raw ?? 'hello').toLowerCase();
  switch (mode) {
    case 'hello':
    case 'hello-bridge':
    case 'bridge':
    case 'custom':
    case 'loan':
    case 'network':
      return mode;
    default:
      throw new Error(`Unknown mode "${mode}". Use: hello | bridge | loan | network`);
  }
}

type CheckResult = { ok: boolean; message: string };

function pass(message: string): CheckResult {
  return { ok: true, message };
}

function fail(message: string): CheckResult {
  return { ok: false, message };
}

async function checkRpc(label: string, url: string | undefined): Promise<CheckResult> {
  if (!url?.trim()) {
    return fail(`${label}: not set`);
  }
  try {
    const provider = new ethers.JsonRpcProvider(url);
    const network = await provider.getNetwork();
    const block = await provider.getBlockNumber();
    return pass(`${label}: reachable (chainId ${network.chainId}, block ${block})`);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return fail(`${label}: unreachable (${msg})`);
  }
}

async function checkProofBuilder(url: string | undefined): Promise<CheckResult> {
  if (!url?.trim()) {
    return fail('PROOF_BUILDER_URL: not set');
  }
  try {
    const response = await fetch(url.replace(/\/$/, ''), { method: 'GET' });
    if (response.ok || response.status === 404 || response.status === 405) {
      return pass(`PROOF_BUILDER_URL: reachable (${response.status})`);
    }
    return fail(`PROOF_BUILDER_URL: HTTP ${response.status}`);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return fail(`PROOF_BUILDER_URL: unreachable (${msg})`);
  }
}

/** ethers surfaces an on-chain revert as CALL_EXCEPTION; anything else is a transport failure. */
function isExecutionRevert(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 'CALL_EXCEPTION';
}

async function checkVerifierPrecompile(creditcoinRpc: string | undefined): Promise<CheckResult> {
  if (!creditcoinRpc?.trim()) {
    return fail('Verifier precompile: skipped (no CREDITCOIN_RPC_URL)');
  }
  try {
    const provider = new ethers.JsonRpcProvider(creditcoinRpc);
    // Frontier precompiles are runtime PrecompileSet entries rather than accounts holding
    // bytecode, so `getCode` returns '0x' for them even on Creditcoin. Probe instead: an
    // empty call makes the precompile revert on the absent selector, while calling an
    // address with nothing behind it succeeds and returns '0x'.
    const result = await provider.call({ to: VERIFIER_PRECOMPILE, data: '0x' });
    return fail(`Native verifier precompile (0xFD2): nothing at address, call returned ${result} (wrong network?)`);
  } catch (error: unknown) {
    if (isExecutionRevert(error)) {
      return pass('Native verifier precompile (0xFD2): present');
    }
    const msg = error instanceof Error ? error.message : String(error);
    return fail(`Verifier precompile check failed (${msg})`);
  }
}

async function checkContractCode(
  label: string,
  rpcUrl: string | undefined,
  address: string | undefined
): Promise<CheckResult> {
  if (!isValidContractAddress(address)) {
    return fail(`${label}: not configured`);
  }
  if (!rpcUrl?.trim()) {
    return fail(`${label}: skipped (no RPC URL)`);
  }
  try {
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const code = await provider.getCode(address!);
    if (code && code !== '0x') {
      return pass(`${label}: contract code found at ${address}`);
    }
    return fail(`${label}: no code at ${address}`);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return fail(`${label}: check failed (${msg})`);
  }
}

function printResults(results: CheckResult[]): boolean {
  let allOk = true;
  for (const result of results) {
    console.log(`${result.ok ? '✓' : '✗'} ${result.message}`);
    if (!result.ok) {
      allOk = false;
    }
  }
  return allOk;
}

async function checkChainKeyAttestation(creditcoinRpc: string | undefined, chainKey: number): Promise<CheckResult> {
  if (!creditcoinRpc?.trim()) {
    return fail('Chain attestation: skipped (no CREDITCOIN_RPC_URL)');
  }
  if (!chainKey) {
    return fail('Chain attestation: SOURCE_CHAIN_KEY missing');
  }
  try {
    const provider = new ethers.JsonRpcProvider(creditcoinRpc);
    const info = new chainInfo.PrecompileChainInfoProvider(provider);
    const latest = await info.getLatestAttestedHeightAndHash(chainKey);
    return pass(`Chain key ${chainKey} attestation: latest height ${latest.height}`);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return fail(`Chain attestation failed (${msg})`);
  }
}

async function runNetworkChecks(): Promise<boolean> {
  const sourceChainKey = Number(process.env.SOURCE_CHAIN_KEY);
  const results: CheckResult[] = [
    sourceChainKey > 0 ? pass(`SOURCE_CHAIN_KEY: ${sourceChainKey}`) : fail('SOURCE_CHAIN_KEY: missing or invalid'),
    await checkRpc('CREDITCOIN_RPC_URL', process.env.CREDITCOIN_RPC_URL),
    await checkProofBuilder(process.env.PROOF_BUILDER_URL),
    await checkVerifierPrecompile(process.env.CREDITCOIN_RPC_URL),
    await checkChainKeyAttestation(process.env.CREDITCOIN_RPC_URL, sourceChainKey),
  ];
  return printResults(results);
}

async function runHelloBridgeChecks(): Promise<boolean> {
  const results: CheckResult[] = [];

  const sourceChainKey = Number(process.env.SOURCE_CHAIN_KEY);
  results.push(
    sourceChainKey > 0 ? pass(`SOURCE_CHAIN_KEY: ${sourceChainKey}`) : fail('SOURCE_CHAIN_KEY: missing or invalid')
  );

  results.push(
    isValidPrivateKey(process.env.CREDITCOIN_WALLET_PRIVATE_KEY)
      ? pass('CREDITCOIN_WALLET_PRIVATE_KEY: set')
      : fail('CREDITCOIN_WALLET_PRIVATE_KEY: missing or invalid')
  );

  results.push(await checkRpc('CREDITCOIN_RPC_URL', process.env.CREDITCOIN_RPC_URL));
  results.push(await checkRpc('SOURCE_CHAIN_RPC_URL', process.env.SOURCE_CHAIN_RPC_URL));
  results.push(await checkProofBuilder(process.env.PROOF_BUILDER_URL));
  results.push(await checkVerifierPrecompile(process.env.CREDITCOIN_RPC_URL));
  results.push(
    await checkContractCode(
      'ASC_MINTER_CONTRACT_ADDRESS',
      process.env.CREDITCOIN_RPC_URL,
      process.env.ASC_MINTER_CONTRACT_ADDRESS
    )
  );
  results.push(
    await checkContractCode(
      'SOURCE_CHAIN_CONTRACT_ADDRESS (Sepolia burner)',
      process.env.SOURCE_CHAIN_RPC_URL,
      process.env.SOURCE_CHAIN_CONTRACT_ADDRESS
    )
  );

  results.push(await checkChainKeyAttestation(process.env.CREDITCOIN_RPC_URL, sourceChainKey));

  return printResults(results);
}

async function runBridgeChecks(): Promise<boolean> {
  const results: CheckResult[] = [];

  const sourceChainKey = Number(process.env.SOURCE_CHAIN_KEY);
  results.push(
    sourceChainKey > 0 ? pass(`SOURCE_CHAIN_KEY: ${sourceChainKey}`) : fail('SOURCE_CHAIN_KEY: missing or invalid')
  );

  results.push(await checkRpc('CREDITCOIN_RPC_URL', process.env.CREDITCOIN_RPC_URL));
  results.push(await checkRpc('SOURCE_CHAIN_RPC_URL', process.env.SOURCE_CHAIN_RPC_URL));
  results.push(await checkProofBuilder(process.env.PROOF_BUILDER_URL));
  results.push(await checkVerifierPrecompile(process.env.CREDITCOIN_RPC_URL));
  results.push(await checkChainKeyAttestation(process.env.CREDITCOIN_RPC_URL, sourceChainKey));

  results.push(
    isValidPrivateKey(process.env.CREDITCOIN_WALLET_PRIVATE_KEY)
      ? pass('CREDITCOIN_WALLET_PRIVATE_KEY: set')
      : fail('CREDITCOIN_WALLET_PRIVATE_KEY: missing or invalid')
  );

  if (isValidContractAddress(process.env.EVM_V1_DECODER_LIBRARY_ADDRESS)) {
    results.push(
      pass(`EVM_V1_DECODER_LIBRARY_ADDRESS: ${process.env.EVM_V1_DECODER_LIBRARY_ADDRESS} (reuse for loan deploy)`)
    );
  } else {
    results.push(
      pass('EVM_V1_DECODER_LIBRARY_ADDRESS: not set (deploy EvmV1Decoder once in custom-contracts tutorial)')
    );
  }

  return printResults(results);
}

async function runLoanChecks(): Promise<boolean> {
  const results: CheckResult[] = [];

  const sourceChainKey = Number(process.env.SOURCE_CHAIN_KEY);
  results.push(
    sourceChainKey > 0 ? pass(`SOURCE_CHAIN_KEY: ${sourceChainKey}`) : fail('SOURCE_CHAIN_KEY: missing or invalid')
  );

  results.push(await checkRpc('CREDITCOIN_RPC_URL', process.env.CREDITCOIN_RPC_URL));
  results.push(await checkRpc('SOURCE_CHAIN_RPC_URL', process.env.SOURCE_CHAIN_RPC_URL));
  results.push(await checkProofBuilder(process.env.PROOF_BUILDER_URL));
  results.push(await checkVerifierPrecompile(process.env.CREDITCOIN_RPC_URL));
  results.push(await checkChainKeyAttestation(process.env.CREDITCOIN_RPC_URL, sourceChainKey));

  results.push(
    isValidPrivateKey(process.env.CREDITCOIN_WALLET_PRIVATE_KEY)
      ? pass('CREDITCOIN_WALLET_PRIVATE_KEY: set')
      : fail('CREDITCOIN_WALLET_PRIVATE_KEY: missing or invalid')
  );
  results.push(
    isValidPrivateKey(process.env.LENDER_WALLET_PRIVATE_KEY)
      ? pass('LENDER_WALLET_PRIVATE_KEY: set')
      : fail('LENDER_WALLET_PRIVATE_KEY: missing or invalid')
  );
  results.push(
    isValidPrivateKey(process.env.BORROWER_WALLET_PRIVATE_KEY)
      ? pass('BORROWER_WALLET_PRIVATE_KEY: set')
      : fail('BORROWER_WALLET_PRIVATE_KEY: missing or invalid')
  );

  if (isValidContractAddress(process.env.EVM_V1_DECODER_LIBRARY_ADDRESS)) {
    results.push(pass(`EVM_V1_DECODER_LIBRARY_ADDRESS: ${process.env.EVM_V1_DECODER_LIBRARY_ADDRESS}`));
  } else {
    results.push(
      pass('EVM_V1_DECODER_LIBRARY_ADDRESS: not set (reuse from bridge tutorial or deploy once on Creditcoin)')
    );
  }

  if (isValidContractAddress(process.env.ASC_LOAN_MANAGER_CONTRACT_ADDRESS)) {
    results.push(
      await checkContractCode(
        'ASC_LOAN_MANAGER_CONTRACT_ADDRESS',
        process.env.CREDITCOIN_RPC_URL,
        process.env.ASC_LOAN_MANAGER_CONTRACT_ADDRESS
      )
    );
  } else {
    results.push(fail('ASC_LOAN_MANAGER_CONTRACT_ADDRESS: not configured'));
  }

  if (isValidContractAddress(process.env.SOURCE_CHAIN_LOAN_CONTRACT_ADDRESS)) {
    results.push(
      await checkContractCode(
        'SOURCE_CHAIN_LOAN_CONTRACT_ADDRESS',
        process.env.SOURCE_CHAIN_RPC_URL,
        process.env.SOURCE_CHAIN_LOAN_CONTRACT_ADDRESS
      )
    );
  } else {
    results.push(fail('SOURCE_CHAIN_LOAN_CONTRACT_ADDRESS: not configured'));
  }

  if (isValidContractAddress(process.env.SOURCE_CHAIN_ERC20_CONTRACT_ADDRESS)) {
    results.push(
      await checkContractCode(
        'SOURCE_CHAIN_ERC20_CONTRACT_ADDRESS',
        process.env.SOURCE_CHAIN_RPC_URL,
        process.env.SOURCE_CHAIN_ERC20_CONTRACT_ADDRESS
      )
    );
  } else {
    results.push(fail('SOURCE_CHAIN_ERC20_CONTRACT_ADDRESS: not configured'));
  }

  return printResults(results);
}

async function main(): Promise<void> {
  let mode: SetupMode;
  try {
    mode = normalizeMode(process.argv[2]);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error(msg);
    process.exit(1);
  }

  loadTutorialEnv(mode);

  console.log(`Tutorial setup check (${mode})\n`);

  let ok: boolean;
  switch (mode) {
    case 'hello':
    case 'hello-bridge':
      ok = await runHelloBridgeChecks();
      break;
    case 'bridge':
    case 'custom':
      ok = await runBridgeChecks();
      break;
    case 'loan':
      ok = await runLoanChecks();
      break;
    case 'network':
      ok = await runNetworkChecks();
      break;
  }

  if (!ok) {
    console.error(`\nFix the items above, then re-run: yarn utils:check_setup ${mode}`);
    process.exit(1);
  }

  console.log('\nSetup looks good. You can continue the tutorial.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
