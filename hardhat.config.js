require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    injectiveTestnet: {
      url: process.env.INJECTIVE_TESTNET_RPC || "https://injective-testnet.rpc.thunderhead.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 588
    },
    injectiveMainnet: {
      url: process.env.INJECTIVE_MAINNET_RPC || "https://injective-rpc.publicnode.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 588
    },
    hardhat: {
      forking: {
        url: process.env.INJECTIVE_MAINNET_RPC || "https://injective-rpc.publicnode.com"
      }
    }
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    gasPrice: 20
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  etherscan: {
    apiKey: {
      injective: process.env.INJECTIVE_API_KEY || "placeholder"
    }
  }
};
