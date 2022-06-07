require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("hardhat-deploy");
require("@appliedblockchain/chainlink-plugins-fund-link");
let secret = require("./secret.json")



// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {

  networks: {
    ganache:{
      url: "http://127.0.0.1:8545",
      chainId:1337
    },
    BSC_Testnet: {
      url: secret.BSCTurl,
      accounts: [secret.key],
    },
    BSC_Mainnet: {
      url: secret.BSCurl,
      accounts: [secret.key]
    },
    rinkeby: {
      url: secret.rinkbyUrl || "",
      chainId: 4,
      accounts: [secret.key],
    },

  },

  namedAccounts: {
    deployer: {
      default: 0,
      4: 0,
    },
    user2: {
      default: 1,
      4: 1,
    },
    user3: {
      default: 2,
      4: 2,
    },
  },

  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },

  etherscan: {
    apiKey: secret.APIKey
  },

  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      {
        version: "0.4.8",
      },
      {
        version: "0.4.11",
      },
      {
        version: "0.8.0"
      },
      {
        version: "0.6.0"
      },
      {
        version: "0.4.24"
      },
      {
        version: "0.6.6"
      },
    ],
  },
  
  mocha: {
    timeout: 10000000,
  },
};
