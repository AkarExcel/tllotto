const { ethers } = require("hardhat");

const ENTRANCE_FEE = ethers.utils.parseEther("0.01")

module.exports = async ({ getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments
    const {deployer} = await getNamedAccounts()
    const args = [  
        "0x6A2AAd07396B36Fe02a22b33cf443582f682c82f", 
        884,
        "0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314",
        "300",
        ENTRANCE_FEE,
        "500000"
    ]

    const raffle = await deploy("Raffle", {
        from: deployer,
        args: args,
        log: true
    })
}