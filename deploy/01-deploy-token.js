const { network, deployments, ethers } = require("hardhat")
const { developmentChains, INITIAL_SUPPLY } = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const ourToken = await deploy("BaseDev", {
    from: deployer,
    args: [
      "0xfCD3842f85ed87ba2889b4D35893403796e67FF1",
      "0x84374a8Eb994cFD039ea26b9124cB4B0548505bE",
      "0x5842c77aec489e4aEd8f98be9d3c02d143c25472",
      "0x3371B4E30f2B25FB8A54A4900Db8AeD106E9dcE4",
    ],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
    gasPrice: 50000000000,
    gasLimit: 30000000,
  })
}

module.exports.tags = ["all", "token"]