require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// Load from .env file
const PRIVATE_KEY   = process.env.PRIVATE_KEY   || "";
const SEPOLIA_RPC   = process.env.SEPOLIA_RPC   || "";
const ETHERSCAN_KEY = process.env.ETHERSCAN_KEY || "";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {

  // ── Solidity version ──────────────────────────────────────────
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,      // optimize for how often functions run
      },
    },
  },

  // ── Networks ──────────────────────────────────────────────────
  networks: {

    // Local hardhat node (for testing)
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },

    // Sepolia testnet (for deployment)
    sepolia: {
      url: SEPOLIA_RPC,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 11155111,
    },

    // Mainnet (when ready for production)
    mainnet: {
      url: process.env.MAINNET_RPC || "",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 1,
    },
  },

  // ── Etherscan verification ────────────────────────────────────
  etherscan: {
    apiKey: {
      sepolia:  ETHERSCAN_KEY,
      mainnet:  ETHERSCAN_KEY,
    },
  },

  // ── Gas reporter ──────────────────────────────────────────────
  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
  },

  // ── Test coverage ─────────────────────────────────────────────
  paths: {
    sources:   "./contracts",
    tests:     "./test",
    cache:     "./cache",
    artifacts: "./artifacts",
  },
};