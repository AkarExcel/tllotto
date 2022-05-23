require("@nomiclabs/hardhat-waffle");
require("hardhat-deploy");
require("@nomiclabs/hardhat-etherscan");
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
    BSC_Testnet: {
      url: secret.url,
      accounts: [secret.key],
    },
    BSC_Mainnet: {
      url: secret.Murl,
      accounts: [secret.key]
    }
  },

  namedAccounts: {
    deployer: {
      default: 0
    }
  },

  etherscan: {
    apiKey: "UMUKJHF3PPW9NEW6SMM4EXPSIPXUSKZB8J"
  },

  solidity: "0.8.7",
};
