import { printBridgeSubmitUsage, runBridgeSubmitQuery } from '../../shared/submit_bridge_query';

async function main() {
  const config = {
    usageCommand: 'yarn custom_bridge:submit_query',
    exampleTxHash: '0x87c97c776a678941b5941ec0cb602a4467ff4a35f77264208575f137cb05b2a7',
    minterAddressEnvVar: 'ASC_CUSTOM_MINTER_CONTRACT_ADDRESS' as const,
  };

  const args = process.argv.slice(2);
  if (args.length !== 1) {
    printBridgeSubmitUsage(config);
    process.exit(1);
  }

  await runBridgeSubmitQuery(config, args[0]);
  process.exit(0);
}

main().catch(console.error);
