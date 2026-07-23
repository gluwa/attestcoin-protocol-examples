import dotenv from 'dotenv';
import { Contract, ethers } from 'ethers';

import loanManagerAbi from '../contracts/abi/USCLoanManager.json';
import { isValidContractAddress, isValidPrivateKey } from '../utils';

dotenv.config({ override: true });

const main = async () => {
  const args = process.argv.slice(2);

  if (args.length > 1) {
    console.error(`
  Usage:
    yarn loan_flow:register_source_contract [SourceLoanContractAddress]

  If no address is provided, SOURCE_CHAIN_LOAN_CONTRACT_ADDRESS from the .env file is used.

  Example:
    yarn loan_flow:register_source_contract 0x5FbDB2315678afecb367f032d93F642f64180aa3
  `);
    process.exit(1);
  }

  // Environment Variables
  const loanManagerContractAddress = process.env.USC_LOAN_MANAGER_CONTRACT_ADDRESS;
  const ccNextRpcUrl = process.env.CREDITCOIN_RPC_URL;
  const ccNextWalletPrivateKey = process.env.CREDITCOIN_WALLET_PRIVATE_KEY;

  // Allow overriding the source loan contract address via CLI, otherwise fall back to the .env value
  const sourceChainLoanContractAddress = args[0] ?? process.env.SOURCE_CHAIN_LOAN_CONTRACT_ADDRESS;

  if (!ccNextRpcUrl) {
    throw new Error('CREDITCOIN_RPC_URL environment variable is not configured or invalid');
  }

  if (!isValidContractAddress(loanManagerContractAddress)) {
    throw new Error('USC_LOAN_MANAGER_CONTRACT_ADDRESS environment variable is not configured or invalid');
  }

  // The loan manager is Ownable, so registration must be done by the owner (the deployer account)
  if (!isValidPrivateKey(ccNextWalletPrivateKey)) {
    throw new Error('CREDITCOIN_WALLET_PRIVATE_KEY environment variable is not configured or invalid');
  }

  if (!isValidContractAddress(sourceChainLoanContractAddress)) {
    throw new Error(
      'No valid source loan contract address provided (pass it as an argument or set SOURCE_CHAIN_LOAN_CONTRACT_ADDRESS in your .env file)'
    );
  }

  // 1. Connect to loan manager contract on the Creditcoin chain
  const ccProvider = new ethers.JsonRpcProvider(ccNextRpcUrl);
  const wallet = new ethers.Wallet(ccNextWalletPrivateKey!, ccProvider);
  const managerContract = new Contract(loanManagerContractAddress!, loanManagerAbi, wallet);

  // 2. Register the source chain loan contract authorized to emit loan events.
  //    The manager will reject any LoanFunded / LoanRepaid events that are not emitted by this address.
  try {
    console.log('Registering source loan contract: ', sourceChainLoanContractAddress);
    const tx = await managerContract.registerSourceLoanContract(sourceChainLoanContractAddress);
    await tx.wait();
    console.log('Source loan contract registered with transaction hash: ', tx.hash);
  } catch (error: any) {
    console.error('Error registering source loan contract: ', error.shortMessage ?? error.message);
    process.exit(1);
  }

  process.exit(0);
};

main().catch(console.error);
