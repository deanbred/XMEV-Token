const { ethers } = require("hardhat")

const networkConfig = {
  default: {
    name: "hardhat",
    keepersUpdateInterval: "30",
  },
  31337: {
    name: "localhost",
    subscriptionId: "588",
    gasLane:
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c", // 30 gwei
    keepersUpdateInterval: "30",
    raffleEntranceFee: ethers.utils.parseEther("0.02"),
    callbackGasLimit: "2500000",
  },
  1: {
    name: "mainnet",
    subscriptionId: "762",
    gasLane:
      "0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92", // 500 gwei
    keepersUpdateInterval: "30",
    raffleEntranceFee: ethers.utils.parseEther("0.01"),
    callbackGasLimit: "2500000",
    vrfCoordinatorV2: "0x271682DEB8C4E0901D1a1550aD2e64D568E69909",
  },
  11155111: {
    name: "sepolia",
    subscriptionId: "2229",
    gasLane:
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c", // 30 gwei
    keepersUpdateInterval: "30",
    raffleEntranceFee: ethers.utils.parseEther("0.01"),
    callbackGasLimit: "2500000",
    vrfCoordinatorV2: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
  },
  5: {
    name: "goerli",
    subscriptionId: "8853",
    gasLane:
      "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15", // 150 gwei
    keepersUpdateInterval: "30",
    raffleEntranceFee: ethers.utils.parseEther("0.02"),
    callbackGasLimit: "2500000",
    vrfCoordinatorV2: "0x2ca8e0c643bde4c2e08ab1fa0da3401adad7734d",
  },
  421613: {
    name: "arb_dev",
    subscriptionId: "",
    gasLane:
      "0x83d1b6e3388bed3d76426974512bb0d270e9542a765cd667242ea26c0cc0b730", // 50 gwei
    keepersUpdateInterval: "30",
    raffleEntranceFee: ethers.utils.parseEther("0.02"),
    callbackGasLimit: "2500000",
    vrfCoordinatorV2: "0x6D80646bEAdd07cE68cab36c27c626790bBcf17f",
  },
  1442: {
    name: "zkevm_dev",
    subscriptionId: "",
    gasLane:
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c", // 30 gwei
    keepersUpdateInterval: "30",
    raffleEntranceFee: ethers.utils.parseEther("0.02"),
    callbackGasLimit: "2500000",
    vrfCoordinatorV2: "",
  },
}

// Fibonacci Sequence 1.12 Billion tokens
const INITIAL_SUPPLY = ethers.BigNumber.from("1123581321000000000000000000")
const VERIFICATION_BLOCK_CONFIRMATIONS = 6

const developmentChains = [
  "hardhat",
  "localhost",
  "sepolia",
  "goerli",
  "arb_dev",
  "zkevm_dev",
]

module.exports = {
  networkConfig,
  VERIFICATION_BLOCK_CONFIRMATIONS,
  developmentChains,
  INITIAL_SUPPLY,
}
