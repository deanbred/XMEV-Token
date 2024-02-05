const { assert, expect, use } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")
!developmentChains.includes(network.name)
console.log(network.name)
console.log(network.config.chainId)
  ? describe.skip
  : describe("Token Unit Test", function () {
      let token, deployer, user1, user2, uniswapV2Pair, tokensToSend, halfToSend
      beforeEach(async function () {
        const accounts = await getNamedAccounts()
        deployer = accounts.deployer
        user1 = accounts.user1
        user2 = accounts.user2

        tTotal = 1123581321 * 10 ** 18
        maxWalletSize = 55000000 * 10 ** 18

        detectSandwich = false
        detectGasBribe = true
        antiWhale = true
        mineBlocks = 3
        avgGasPrice = 1 * 10 ** 12
        gasDelta = 25
        maxSample = 10
        txCounter = 1
        tokensToSend = ethers.utils.parseEther("100")

        await deployments.fixture("all")
        token = await hre.ethers.getContract("XMEV", deployer)
        await token.transferOwnership(user2)
        //await token.renounceOwnership()

        uniswapV2Pair = await token.uniswapV2Pair()
        uniswapV2Router = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
      })

      it("Was deployed successfully ", async () => {
        assert(token.address)
      })

      describe("* Constructor *", () => {
        it("Has correct supply of tokens ", async () => {
          const totalSupply = await token.totalSupply()
          console.log(
            `* Supply from contract: ${ethers.utils.commify(
              totalSupply / 1e18
            )}`
          )
        })
        it("Initializes the token with the correct name and symbol ", async () => {
          const name = (await token.name()).toString()
          assert.equal(name, "XMEV")
          console.log(`* Name from contract is: ${name}`)

          const symbol = (await token.symbol()).toString()
          assert.equal(symbol, "XMEV")
          console.log(`* Symbol from contract is: $${symbol}`)
        })
        it("Creates a Uniswap pair for the token ", async () => {
          console.log(`* Pair address from contract: ${uniswapV2Pair}`)
        })
        it("Mints correct number of tokens to deployer ", async () => {
          const deployerBalance = await token.balanceOf(deployer)
          console.log(`* Deployer balance from contract: ${deployerBalance}`)
        })
      })

      describe("* GAS *", () => {
        it("Should calculate the average gas price of 10 transfers", async () => {
          //await token.transferOwnership(deployer)

          /*           await token.setMEV(
            detectSandwich,
            detectGasBribe,
            antiWhale,
            mineBlocks,
            avgGasPrice,
            gasDelta,
            maxSample,
            txCounter
          ) */

          for (let i = 1; i < 10; i++) {
            await ethers.provider.send("evm_mine")

            const transactionResponse = await token.transfer(
              user1,
              tokensToSend
            )

            const transactionReceipt = await transactionResponse.wait()
            const { gasUsed, effectiveGasPrice } = transactionReceipt
            const transferGasCost = gasUsed.mul(effectiveGasPrice)

            console.log(`* gasUsed ${i}: ${gasUsed}`)
            console.log(`* effectiveGasPrice ${i}: ${effectiveGasPrice}`)
            console.log(`* transferGasCost ${i}: ${transferGasCost}`)
            console.log("-------------")
          }
        })

        it("Should revert if gas bribe is detected", async () => {
          const transactionResponse = await token.transfer(user1, tokensToSend)

          const transactionReceipt = await transactionResponse.wait()
          const { gasUsed, effectiveGasPrice } = transactionReceipt
          const transferGasCost = gasUsed.mul(effectiveGasPrice)
          const bribe = effectiveGasPrice.add(
            effectiveGasPrice.mul(gasDelta + 50).div(100)
          )

          console.log(`gasUsed: ${gasUsed}`)
          console.log(`effectiveGasPrice(tx.gasprice): ${effectiveGasPrice}`)
          console.log(`transferGasCost: ${transferGasCost}`)
          console.log(`bribe-test: ${bribe}`)
          console.log("---------------------------")

          await ethers.provider.send("evm_mine")

          await expect(
            token.transfer(user1, tokensToSend, {
              gasPrice: bribe,
            })
          ).to.be.revertedWith("XMEV: Gas Bribe Detected")
        })
      })

      describe("* Transfers *", () => {
        const halfToSend = ethers.utils.parseEther("0.5")

        it("Should transfer tokens successfully to an address", async () => {
          const startBalance = await token.balanceOf(user1)
          console.log(`startBalance: ${startBalance}`)

          await token.transfer(user1, tokensToSend)
          const afterTax = tokensToSend.mul(99).div(100)

          expect(await token.balanceOf(user1)).to.equal(afterTax)
          const endBalance = await token.balanceOf(user1)
          console.log(`endBalance: ${endBalance / 1e18}`)
        })

        it("Should prevent transfers over maxWallet", async () => {
          console.log(`maxWallet: ${maxWalletSize}`)
          const over = "55000001000000000000000000"

          await expect(token.transfer(user1, over)).to.be.revertedWith(
            "XMEV: Exceeds maxWalletSize"
          )
        })

        it("Should prevent 2 transfers in the same block", async () => {
          await token.transfer(user1, tokensToSend)

          await expect(token.transfer(user1, tokensToSend)).to.be.revertedWith(
            "XMEV: Sandwich Attack Detected"
          )
        })

        it("Should allow 2 transfers after block delay", async () => {
          await token.transfer(user1, tokensToSend)

          for (let i = 0; i < mineBlocks; i++) {
            await ethers.provider.send("evm_mine", [])
          }

          await expect(token.transfer(user1, tokensToSend)).to.not.be.reverted
        })

        it("Should prevent 2 transferFroms in the same block", async () => {
          await token.approve(deployer, tokensToSend)
          await token.transferFrom(deployer, user1, tokensToSend)
          await token.approve(deployer, tokensToSend)

          await expect(
            token.transferFrom(deployer, user1, tokensToSend)
          ).to.be.revertedWith("XMEV: Sandwich Attack Detected")
        })

        it("Should allow 2 transferFroms after block delay", async () => {
          await token.approve(deployer, tokensToSend)
          await token.transferFrom(deployer, user1, halfToSend)

          for (let j = 0; j < mineBlocks; j++) {
            await ethers.provider.send("evm_mine")
          }

          await expect(token.transferFrom(deployer, user1, halfToSend)).to.not
            .be.reverted
        })

        it("Should emit transfer event when an transfer occurs", async () => {
          await expect(token.transfer(user1, tokensToSend)).to.emit(
            token,
            "Transfer"
          )
        })
      })

      describe("* Allowances *", () => {
        const tokensToSpend = ethers.utils.parseEther("1")
        const overDraft = ethers.utils.parseEther("1.1")

        beforeEach(async () => {
          playerToken = await ethers.getContract("XMEV", user1)
        })
        it("Should set allowance accurately", async () => {
          await token.approve(user1, tokensToSpend)
          const allowance = await token.allowance(deployer, user1)
          console.log(`Allowance from contract: ${allowance / 1e18}`)
          assert.equal(allowance.toString(), tokensToSpend)
        })

        it("Should approve other address to spend token", async () => {
          await token.approve(user1, tokensToSpend)
          const allowance = await token.allowance(deployer, user1)

          await playerToken.transferFrom(deployer, user1, tokensToSpend)

          const afterTax = tokensToSend.mul(99).div(100)
          console.log(`afterTax: ${afterTax}`)

          expect(await playerToken.balanceOf(user1)).to.equal(afterTax)
          console.log(`Tokens approved from contract: ${tokensToSpend}`)
        })

        it("Should not allow unnaproved user to do transfers", async () => {
          await expect(
            playerToken.transferFrom(deployer, user1, tokensToSpend)
          ).to.be.revertedWith("ERC20InsufficientAllowance")
        })

        it("Should not allow user to go over the allowance", async () => {
          await token.approve(user1, tokensToSpend)
          await expect(
            playerToken.transferFrom(deployer, user1, overDraft)
          ).to.be.revertedWith("ERC20InsufficientAllowance")
        })

        it("Should emit approval event when an approval occurs", async () => {
          await expect(token.approve(user1, tokensToSpend)).to.emit(
            token,
            "Approval"
          )
        })
      })
    })
