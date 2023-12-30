accounts = await getNamedAccounts()
deployer = accounts.deployer
user1 = accounts.user1
user2 = accounts.user2
tokensToSend = ethers.utils.parseEther("100")
antiMEV = await ethers.getContract("AntiMEV", deployer)
ethAmount = ethers.utils.parseEther("5")
tokenAmount = await antiMEV.balanceOf(deployer)
tx = await antiMEV.addLiquidity(ethAmount, tokenAmount, { gasLimit: 3000000 })
pair = await antiMEV.uniswapV2Pair()

tx = await antiMEV.transfer(user1, tokensToSend)
tx = await antiMEV.setVIP(deployer, false)
tx = await antiMEV.isVIP(deployer)
tx = await antiMEV.isBOT(deployer)
tx = await ethers.provider.send("evm_mine", [])
ethers.provider.blockNumber

tx = await antiMEV.approve(user1, tokensToSend)
tx = await antiMEV.approve(user2, tokensToSend)

maxWallet = await antiMEV.maxWallet()
tx = await antiMEV.transfer(user1, maxWallet + 1)

tx = await antiMEV.setVIP(deployer, false)
tx = await antiMEV.setVIP(deployer, true)

tx = await antiMEV.setBOT(deployer, false)
tx = await antiMEV.setBOT(deployer, true)

tx = await antiMEV.setVIP(user1, false)
tx = await antiMEV.setVIP(user1, true)

tx = await antiMEV.setBOT(user1, false)
tx = await antiMEV.setBOT(user1, true)

tx = await antiMEV.transfer(user1, tokensToSend)
tx = await antiMEV.transfer(user1, tokensToSend)

transactionResponse = await antiMEV.transfer(user1, tokensToSend)
transactionReceipt = await transactionResponse.wait()
const { gasUsed, effectiveGasPrice } = transactionReceipt
transferGasCost = gasUsed.mul(effectiveGasPrice)
bribe = effectiveGasPrice.add(effectiveGasPrice.mul(gasDelta + 50).div(100))
tx = antiMEV.transfer(user1, tokensToSend, {
  gasPrice: bribe,
  gasLimit: 3000000,
})

tx = await antiMEV.isBOT("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")

ethAmount = ethers.utils.parseEther("5")
tokenAmount = ethers.utils.parseEther("100000000")
tx = await antiMEV.uniswapV2Router.addLiquidityETH(
  { value: ethAmount, gasLimit: 3000000, gasPrice: 500000000000 },
  tokenAmount,
  0,
  0,
  deployer,
  9999999999
)

tx = await antiMEV.addLiquidity(ethAmount, tokenAmount)
// uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);

await antiMEV.approve(user1, tokensToSend)
await antiMEV.approve(user2, tokensToSend)

const ourToken = await deploy("AntiMEV", {
  from: deployer,
  args: [
    "0xc2657176e213ddf18646efce08f36d656abe3396",
    "0x8b30998a9492610f074784aed7afdd682b23b416",
    "0xe276d3ea57c5af859e52d51c2c11f5decb4c4838",
  ],
})

if (detectMEV) {
  if (
    !isVIP[tx.origin] &&
    to != address(uniswapV2Router) &&
    to != address(uniswapV2Pair)
  ) {
    console.log("lastTxBlock: %s", lastTxBlock[tx.origin])
    console.log("block.number: %s", block.number)

    // test for sandwich attack
    if (lastTxBlock[tx.origin] == block.number - 1) {
      _setBOT(tx.origin, true)
      revert("AntiMEV: Detected sandwich attack, BOT added")
    }
    require(lastTxBlock[tx.origin] + mineBlocks <
      block.number, "AntiMEV: Detected sandwich attack, mine more blocks")
    lastTxBlock[tx.origin] = block.number

    // test for gas bribe
    txCounter += 1
    console.log("tx.gasprice: %s", tx.gasprice)
    avgGasPrice =
      (avgGasPrice * (txCounter - 1)) / txCounter + tx.gasprice / txCounter
    require(tx.gasprice <=
      avgGasPrice.add(
        avgGasPrice.mul(gasDelta).div(100)
      ), "AntiMEV: Detected gas bribe")
  }
}

//setBOT(address(0xe3DF3043f1cEfF4EE2705A6bD03B4A37F001029f), true);
//setBOT(address(0xE545c3Cd397bE0243475AF52bcFF8c64E9eAD5d7), true);
