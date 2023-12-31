const { network, deployments, ethers } = require("hardhat")
const { developmentChains, INITIAL_SUPPLY } = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const ourToken = await deploy("XMEV", {
    from: deployer,
    args: [
      "0xc2657176e213DDF18646eFce08F36D656aBE3396",
      "0x8B30998a9492610F074784Aed7aFDd682B23B416",
      "0xe276d3ea57c5AF859e52d51C2C11f5deCb4C4838",
    ],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
    gasPrice: 50000000000,
    gasLimit: 30000000,
  })
}

module.exports.tags = ["all", "token"]