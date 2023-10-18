import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'dotenv/config';
import 'hardhat-gas-reporter';
import 'solidity-coverage';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-etherscan';

const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || 'key';
const OP_GOERLI_RPC_URL =
   process.env.OP_GOERLI_RPC_URL ||
   'https://opt-goerli.g.alchemy.com/v2/YOUR-API-KEY';
const OP_RPC_URL =
   process.env.OP_RPC_URL ||
   'https://opt-mainnet.g.alchemy.com/v2/YOUR-API-KEY';
const BASE_RPC_URL =
   process.env.BASE_RPC_URL ||
   'https://base-mainnet.g.alchemy.com/v2/YOUR-API-KEY';
const MNEMONIC = process.env.MNEMONIC || 'your mnemonic';
const REPORT_GAS = process.env.REPORT_GAS || false;
// const ETHERSCAN_API_KEY =
//    process.env.ETHERSCAN_API_KEY || 'Your etherscan API key';

const config: HardhatUserConfig = {
   solidity: '0.8.17',
   networks: {
      localhost: {
         chainId: 31337,
      },
      opGoerli: {
         url: OP_GOERLI_RPC_URL,
         accounts: { mnemonic: MNEMONIC },
         chainId: 420,
         gas: 3000000,
      },
      optimism: {
         url: OP_RPC_URL,
         accounts: { mnemonic: MNEMONIC },
         chainId: 10,
      },
      base: {
         url: BASE_RPC_URL,
         accounts: { mnemonic: MNEMONIC },
         chainId: 8453,
      },
   },

   gasReporter: {
      enabled: true,
      outputFile: 'gas-report.txt',
      noColors: true,
      currency: 'USD',
      coinmarketcap: COINMARKETCAP_API_KEY,
   },
};

export default config;
