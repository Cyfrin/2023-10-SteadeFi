import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";
import * as dotenv from "dotenv";
import "@nomicfoundation/hardhat-foundry";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.21",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      avalanche: process.env.SNOWTRACE_API_KEY ? process.env.SNOWTRACE_API_KEY : "",
      arbitrumOne: process.env.ARBISCAN_API_KEY ? process.env.ARBISCAN_API_KEY : "",
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    hardhat: {
      forking: {
        url: "https://api.avax.network/ext/bc/C/rpc",
        enabled: true,
        blockNumber: 33650262,
      },
      gasPrice: 'auto',
      accounts: {
        accountsBalance: "100000000000000000000000000000000"
      }
    },
    avalancheFujiTestnet: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      gasPrice: "auto",
      accounts: process.env.PRIVATE_KEY_DEPLOYER !== undefined ? [process.env.PRIVATE_KEY_DEPLOYER] : [],
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      gasPrice: 'auto',
      accounts: process.env.PRIVATE_KEY_DEPLOYER !== undefined ? [process.env.PRIVATE_KEY_DEPLOYER] : [],
    },
    arbitrumOne: {
      url: "https://arb1.arbitrum.io/rpc",
      gasPrice: 'auto',
      accounts: process.env.PRIVATE_KEY_DEPLOYER !== undefined ? [process.env.PRIVATE_KEY_DEPLOYER] : [],
      chainId: 42161
    },
  },
};

export default config;
