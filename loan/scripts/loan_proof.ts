import { Contract, ethers } from 'ethers';

import loanManagerAbi from '../contracts/abi/ASCLoanManager.json';
import {
  computeGasLimitForLoanManager,
  generateProofFor,
  isValidContractAddress,
  isValidPrivateKey,
  submitFundProofToLoanManager,
  submitRepayProofToLoanManager,
} from '../../shared/utils';

/** Matches LoanStatus in LoanTypes.sol */
const LOAN_STATUS_CREATED = 0;
const LOAN_STATUS_FUNDED = 1;
const LOAN_STATUS_PARTLY_REPAID = 2;
const LOAN_STATUS_REPAID = 3;

export type LoanProofKind = 'fund' | 'repay';

async function getLoanStatus(managerContract: Contract, loanId: number): Promise<number> {
  const order = await managerContract.getLoanOrder(loanId);
  return Number(order[6]);
}

/**
 * Prove a source-chain fund/repay tx and submit to ASCLoanManager on Creditcoin.
 * Uses the tx hash + proof builder (no wide eth_getLogs scans on Sepolia).
 */
export async function submitLoanProofAfterTx(loanId: number, txHash: string, kind: LoanProofKind): Promise<void> {
  const proofBuilderUrl = process.env.PROOF_BUILDER_URL;
  const sourceChainRpcUrl = process.env.SOURCE_CHAIN_RPC_URL;
  const ccNextRpcUrl = process.env.CREDITCOIN_RPC_URL;
  const ccNextWalletPrivateKey = process.env.CREDITCOIN_WALLET_PRIVATE_KEY;
  const loanManagerContractAddress = process.env.ASC_LOAN_MANAGER_CONTRACT_ADDRESS;
  const sourceChainKey = Number(process.env.SOURCE_CHAIN_KEY);

  if (!proofBuilderUrl) {
    throw new Error('PROOF_BUILDER_URL environment variable is not configured or invalid');
  }
  if (!sourceChainRpcUrl) {
    throw new Error('SOURCE_CHAIN_RPC_URL environment variable is not configured or invalid');
  }
  if (!ccNextRpcUrl) {
    throw new Error('CREDITCOIN_RPC_URL environment variable is not configured or invalid');
  }
  if (!isValidPrivateKey(ccNextWalletPrivateKey)) {
    throw new Error('CREDITCOIN_WALLET_PRIVATE_KEY environment variable is not configured or invalid');
  }
  if (!isValidContractAddress(loanManagerContractAddress)) {
    throw new Error('ASC_LOAN_MANAGER_CONTRACT_ADDRESS environment variable is not configured or invalid');
  }
  if (isNaN(sourceChainKey)) {
    throw new Error('SOURCE_CHAIN_KEY environment variable is not configured or invalid');
  }

  const ccProvider = new ethers.JsonRpcProvider(ccNextRpcUrl);
  const sourceChainProvider = new ethers.JsonRpcProvider(sourceChainRpcUrl);
  const ccWallet = new ethers.Wallet(ccNextWalletPrivateKey!, ccProvider);
  const managerContract = new Contract(loanManagerContractAddress!, loanManagerAbi, ccWallet);

  const status = await getLoanStatus(managerContract, loanId);

  if (kind === 'fund') {
    if (status !== LOAN_STATUS_CREATED) {
      console.log(
        `Loan ${loanId} is not in Created status on Creditcoin (status=${status}), skipping fund proof submission.`
      );
      if (status === LOAN_STATUS_FUNDED || status === LOAN_STATUS_PARTLY_REPAID) {
        console.log(`Loan ${loanId} has been marked as funded on Creditcoin.`);
      }
      return;
    }
  } else {
    if (status === LOAN_STATUS_REPAID) {
      console.log(`Loan ${loanId} has been marked as fully repaid on Creditcoin.`);
      return;
    }
    if (status !== LOAN_STATUS_FUNDED && status !== LOAN_STATUS_PARTLY_REPAID) {
      throw new Error(`Loan ${loanId} is not in a repayable status on Creditcoin (status=${status})`);
    }
  }

  console.log(
    `Detected ${kind === 'fund' ? 'LoanFunded' : 'LoanRepaid'} event for loanId: ${loanId}, tx hash: ${txHash}`
  );

  const proofResult = await generateProofFor(txHash, sourceChainKey, proofBuilderUrl, ccProvider, sourceChainProvider);

  if (!proofResult.success) {
    throw new Error(`Failed to generate proof: ${proofResult.error}`);
  }

  const isRepayment = kind === 'repay';
  const gasLimit = await computeGasLimitForLoanManager(
    ccProvider,
    managerContract,
    proofResult.data!,
    ccWallet.address,
    isRepayment
  );

  const response = isRepayment
    ? await submitRepayProofToLoanManager(managerContract, proofResult.data!, gasLimit)
    : await submitFundProofToLoanManager(managerContract, proofResult.data!, gasLimit);

  await response.wait?.();

  if (kind === 'fund') {
    console.log(`Marked loan ${loanId} as funded on Creditcoin, tx hash: ${response.hash}`);
    console.log(`Loan ${loanId} has been marked as funded on Creditcoin.`);
    return;
  }

  console.log(`Marked loan ${loanId} as repaid on Creditcoin, tx hash: ${response.hash}`);

  const newStatus = await getLoanStatus(managerContract, loanId);
  if (newStatus === LOAN_STATUS_REPAID) {
    console.log(`Loan ${loanId} has been marked as fully repaid on Creditcoin.`);
  } else if (newStatus === LOAN_STATUS_PARTLY_REPAID) {
    const order = await managerContract.getLoanOrder(loanId);
    const repaidAmount = order[7];
    console.log(`Loan ${loanId} has been partially repaid on Creditcoin. Amount repaid: ${repaidAmount}`);
  }
}
