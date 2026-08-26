import dotenv from 'dotenv';
import { Contract, ethers, InterfaceAbi } from 'ethers';

import ASCMinterABI from '../bridge/contracts/abi/ASCMinter.json';
import {
  generateProofFor,
  submitProofToMinterAndAwait,
  computeGasLimitForMinter,
  isValidPrivateKey,
  isValidContractAddress,
} from './utils';

dotenv.config({ override: true });

export type BridgeSubmitConfig = {
  usageCommand: string;
  exampleTxHash: string;
  minterAddressEnvVar: 'ASC_MINTER_CONTRACT_ADDRESS' | 'ASC_CUSTOM_MINTER_CONTRACT_ADDRESS';
};

export function printBridgeSubmitUsage(config: BridgeSubmitConfig): void {
  console.error(`
  Usage:
    ${config.usageCommand} <Transaction_Hash>

  Example:
    ${config.usageCommand} ${config.exampleTxHash}
  `);
}

export async function runBridgeSubmitQuery(
  config: BridgeSubmitConfig,
  transactionHash: string
): Promise<void> {
  if (!transactionHash.startsWith('0x') || transactionHash.length !== 66) {
    throw new Error('Invalid transaction hash provided');
  }

  const ccNextPrivateKey = process.env.CREDITCOIN_WALLET_PRIVATE_KEY;
  if (!isValidPrivateKey(ccNextPrivateKey)) {
    throw new Error('CREDITCOIN_WALLET_PRIVATE_KEY environment variable is not configured or invalid');
  }

  const sourceChainKey = Number(process.env.SOURCE_CHAIN_KEY);
  if (!sourceChainKey) {
    throw new Error('SOURCE_CHAIN_KEY environment variable is not configured or invalid');
  }

  const proofBuilderUrl = process.env.PROOF_BUILDER_URL;
  if (!proofBuilderUrl) {
    throw new Error('PROOF_BUILDER_URL is not configured or invalid');
  }

  const creditcoinRpcUrl = process.env.CREDITCOIN_RPC_URL;
  if (!creditcoinRpcUrl) {
    throw new Error('CREDITCOIN_RPC_URL environment variable is not configured or invalid');
  }

  const minterContractAddress = process.env[config.minterAddressEnvVar];
  if (!isValidContractAddress(minterContractAddress)) {
    throw new Error(`${config.minterAddressEnvVar} is not configured or invalid`);
  }

  const sourceChainRpcUrl = process.env.SOURCE_CHAIN_RPC_URL;
  if (!sourceChainRpcUrl) {
    throw new Error('SOURCE_CHAIN_RPC_URL environment variable is not configured or invalid');
  }

  const ccProvider = new ethers.JsonRpcProvider(creditcoinRpcUrl);
  const sourceChainProvider = new ethers.JsonRpcProvider(sourceChainRpcUrl);

  const proofResult = await generateProofFor(
    transactionHash,
    sourceChainKey,
    proofBuilderUrl,
    ccProvider,
    sourceChainProvider
  );

  if (!proofResult.success) {
    throw new Error(`Failed to generate proof: ${proofResult.error}`);
  }

  const wallet = new ethers.Wallet(ccNextPrivateKey!, ccProvider);
  const contractABI = ASCMinterABI as unknown as InterfaceAbi;
  const minterContract = new Contract(minterContractAddress!, contractABI, wallet);

  const proofData = proofResult.data!;
  const gasLimit = await computeGasLimitForMinter(ccProvider, minterContract, proofData, wallet.address);
  await submitProofToMinterAndAwait(minterContract, proofData, gasLimit);
}
