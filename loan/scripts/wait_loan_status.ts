import { Contract, ethers } from 'ethers';

import loanManagerAbi from '../contracts/abi/ASCLoanManager.json';
import { isValidContractAddress } from '../../shared/utils';
import { loadEnv } from '../../shared/env';

loadEnv('loan');

const STATUS_NAMES = ['Created', 'Funded', 'PartlyRepaid', 'Repaid', 'Expired'] as const;
type StatusName = (typeof STATUS_NAMES)[number];

function parseStatusName(name: string): number {
  const index = STATUS_NAMES.indexOf(name as StatusName);
  if (index < 0) {
    throw new Error(`Invalid status "${name}". Expected one of: ${STATUS_NAMES.join(', ')}`);
  }
  return index;
}

const main = async () => {
  const args = process.argv.slice(2);

  if (args.length < 2 || args.length > 3) {
    console.error(`
  Usage:
    yarn loan_flow:wait_loan_status <LoanId> <Status> [TimeoutSeconds]

  Example:
    yarn loan_flow:wait_loan_status 1 Funded 1200
  `);
    process.exit(1);
  }

  const loanId = Number(args[0]);
  const expectedStatus = parseStatusName(args[1]);
  const timeoutSecs = args[2] ? Number(args[2]) : 1200;

  if (isNaN(loanId) || loanId < 0) {
    throw new Error('Invalid Loan ID provided');
  }
  if (isNaN(timeoutSecs) || timeoutSecs <= 0) {
    throw new Error('Invalid timeout provided');
  }

  const ccNextRpcUrl = process.env.CREDITCOIN_RPC_URL;
  const loanManagerContractAddress = process.env.ASC_LOAN_MANAGER_CONTRACT_ADDRESS;

  if (!ccNextRpcUrl) {
    throw new Error('CREDITCOIN_RPC_URL environment variable is not configured or invalid');
  }
  if (!isValidContractAddress(loanManagerContractAddress)) {
    throw new Error('ASC_LOAN_MANAGER_CONTRACT_ADDRESS environment variable is not configured or invalid');
  }

  const ccProvider = new ethers.JsonRpcProvider(ccNextRpcUrl);
  const managerContract = new Contract(loanManagerContractAddress!, loanManagerAbi, ccProvider);

  const deadline = Date.now() + timeoutSecs * 1000;
  const expectedName = STATUS_NAMES[expectedStatus];

  while (Date.now() < deadline) {
    const currentOrder = await managerContract.getLoanOrder(loanId);
    const status = Number(currentOrder[6]);
    const statusName = STATUS_NAMES[status] ?? String(status);

    if (status === expectedStatus) {
      console.log(`Loan ${loanId} reached status ${statusName} on Creditcoin.`);
      process.exit(0);
    }

    console.log(`Waiting for loan ${loanId} status ${expectedName} (current: ${statusName})...`);
    await new Promise((resolve) => setTimeout(resolve, 15000));
  }

  const finalOrder = await managerContract.getLoanOrder(loanId);
  const finalStatus = Number(finalOrder[6]);
  console.error(
    `Timed out after ${timeoutSecs}s waiting for loan ${loanId} status ${expectedName} (last status: ${STATUS_NAMES[finalStatus] ?? finalStatus}).`
  );
  process.exit(1);
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
