require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

// Load .env.mainnet if deploying to mainnet, otherwise .env
const envFile = process.env.HARDHAT_NETWORK === "bscMainnet" || process.argv.includes("bscMainnet")
  ? ".env.mainnet"
  : ".env";
require("dotenv").config({ path: envFile });

const BSC_TESTNET_RPC_URL =
  process.env.BSC_TESTNET_RPC_URL || "https://data-seed-prebsc-1-s1.bnbchain.org:8545";
const BSC_MAINNET_RPC_URL =
  process.env.BSC_MAINNET_RPC_URL || "https://bsc-dataseed1.bnbchain.org:8545";
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || process.env.BSCSCAN_API_KEY || "";

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 31338,
      mining: { auto: true, interval: 0 },
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31338,
    },
    bscTestnet: {
      url: BSC_TESTNET_RPC_URL,
      chainId: 97,
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
      gasPrice: 5000000000,
    },
    bscMainnet: {
      url: BSC_MAINNET_RPC_URL,
      chainId: 56,
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
      gasPrice: 3000000000,
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
};
