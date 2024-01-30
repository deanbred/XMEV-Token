const chai = require("chai")
const expect = chai.expect

describe("XMEV", function () {
  let XMEV
  let owner
  let addr1
  let addr2
  let addrs

  beforeEach(async function () {
    XMEV = await XMEV.deployed()
    ;[owner, addr1, addr2, ...addrs] = await ethers.getSigners()
  })

  describe("_avgGasPrice calculation", function () {
    it("should correctly calculate and store _avgGasPrice", async function () {
      const initialAvgGasPrice = await XMEV._avgGasPrice()
      const initialTxCounter = await XMEV._txCounter()

      // Simulate a transaction
      await XMEV.transfer(addr1.address, 100)

      const finalAvgGasPrice = await XMEV._avgGasPrice()
      const finalTxCounter = await XMEV._txCounter()

      // Calculate expected _avgGasPrice
      const expectedAvgGasPrice =
        (initialAvgGasPrice * initialTxCounter + tx.gasprice) / finalTxCounter

      expect(finalAvgGasPrice).to.equal(expectedAvgGasPrice)
    })
  })

  describe("XMEV Token Contract", function () {
    let XMEV, owner, addr1, addr2, addrs

    it("Should transfer 1% tax to owner on transfer", async function () {
      // Open trading
      await XMEV.openTrading()

      // Transfer some tokens from addr1 to addr2
      const transferAmount = ethers.utils.parseEther("100")
      await XMEV.connect(addr1).transfer(addr2.address, transferAmount)

      // Calculate the expected tax amount
      const expectedTax = transferAmount.div(100)

      // Get the devWallet balance
      const devWalletBalance = await XMEV.balanceOf(devWallet.address)

      // Check if the devWallet balance is equal to the expected tax
      expect(devWalletBalance).to.equal(expectedTax)
    })
  })
})
