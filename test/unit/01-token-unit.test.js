const { assert, expect, use } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")
!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Token Unit Test", function () {
      let token,
        name,
        uniswapRouter,
        uniswapV2Pair,
        deployer,
        user1,
        user2,
        detectMEV,
        mineBlocks,
        gasDelta,
        maxSample,
        averageGasPrice,
        tokensToSend,
        halfToSend
      beforeEach(async function () {
        const accounts = await getNamedAccounts()
        deployer = accounts.deployer
        user1 = accounts.user1
        user2 = accounts.user2
        detectMEV = true
        mineBlocks = 3
        gasDelta = 25
        averageGasPrice = 1e9
        maxSample = 10
        tokensToSend = ethers.utils.parseEther("100")

        await deployments.fixture("all")

        // Deploy token
        token = await hre.ethers.getContract("token", deployer)

        uniswapV2Pair = await token.uniswapV2Pair()
        uniswapV2Router = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

        // add deployer as VIP
        //await token.setVIP(deployer, true)
        // add user1 as VIP
        //await token.setVIP(user1, true)
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
          assert.equal(name, "BaseDev")
          console.log(`* Name from contract is: ${name}`)

          const symbol = (await token.symbol()).toString()
          assert.equal(symbol, "BASEDEV")
          console.log(`* Symbol from contract is: $${symbol}`)
        })
        it("Creates a Uniswap pair for the token ", async () => {
          console.log(`* Pair address from contract: ${uniswapV2Pair}`)
        })
        it("Adds 3 ETH liquidity to the Uniswap pair ", async () => {
          const tokenAmount = await token.balanceOf(deployer)
          const ethAmount = ethers.utils.parseEther("3")
          console.log(`* Token amount: ${tokenAmount / 1e18}`)
          console.log(`* Eth amount: ${ethAmount / 1e18}`)
          await token.addLiquidity(tokenAmount, ethAmount)
        })
      })

      describe("* BOT *", () => {
        it("Should add to bots if two tranfers in the same block", async () => {
          await token.setVIP(deployer, false)
          await token.transfer(user1, tokensToSend)
          await expect(
            token.transfer(user1, tokensToSend)
          ).to.be.revertedWith("token: Detected sandwich attack, BOT added")
        })

        it("Should prevent bots from buying", async () => {
          await token.setBOT(user1, true)
          await expect(
            token.transfer(user1, tokensToSend)
          ).to.be.revertedWith("token: Known MEV Bot")
          await token.setBOT(user1, false)
          await expect(token.transfer(user1, tokensToSend)).to.not.be.reverted
        })
      })

      describe("* VIP *", () => {
        it("Should allow VIP to do 2 transfers in the same block", async () => {
          await token.setVIP(deployer, true)
          await token.setVIP(user1, true)
          await token.transfer(user1, tokensToSend)
          expect(await token.transfer(user1, tokensToSend)).to.not.be.reverted
        })

        it("Should not allow regular user to do 2 transfers", async () => {
          await token.setVIP(deployer, false)
          await token.setVIP(user1, false)
          await token.transfer(user1, tokensToSend)

          expect(
            await token.transfer(user1, tokensToSend)
          ).to.be.revertedWith("token: Detected sandwich attack, BOT added")
        })

        it("Should allow VIP to transfer with a gas bribe", async () => {
          //await token.setVIP(deployer, true)
          await token.setMEV(mineBlocks, gasDelta, maxSample, averageGasPrice)
          console.log(`* mineBlocks: ${mineBlocks}`)
          console.log(`* gasDelta: ${gasDelta}`)
          console.log(`* maxSample: ${maxSample}`)
          console.log(`* averageGasPrice: ${averageGasPrice}`)
          console.log("---------------------------")

          const transactionResponse = await token.transfer(
            user1,
            tokensToSend
          )
          const transactionReceipt = await transactionResponse.wait()
          const { gasUsed, effectiveGasPrice } = transactionReceipt
          const transferGasCost = gasUsed.mul(effectiveGasPrice)
          const bribe = effectiveGasPrice.add(
            effectiveGasPrice.mul(gasDelta + 50).div(100)
          )

          console.log(`* gasUsed: ${gasUsed}`)
          console.log(`* effectiveGasPrice(tx.gasprice): ${effectiveGasPrice}`)
          console.log(`* transferGasCost: ${transferGasCost}`)
          console.log(`* bribe-test: ${bribe}`)
          console.log("---------------------------")

          expect(
            await token.transfer(user1, tokensToSend, {
              gasPrice: bribe,
            })
          ).to.not.be.reverted
        })
      })

      describe("* GAS *", () => {
        it("Should calculate the average gas price of 10 transfers", async () => {
          for (let i = 1; i < 11; i++) {
            for (let j = 0; j < mineBlocks; j++) {
              await ethers.provider.send("evm_mine")
            }

            const transactionResponse = await token.transfer(
              user1,
              tokensToSend
            )

            await token.setVIP(deployer, false)
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
          await token.setMEV(
            detectMEV,
            mineBlocks,
            gasDelta,
            maxSample,
            averageGasPrice
          )
          console.log(`* detectMEV: ${detectMEV}`)
          console.log(`* mineBlocks: ${mineBlocks}`)
          console.log(`* gasDelta: ${gasDelta}`)
          console.log(`* maxSample: ${maxSample}`)
          console.log(`* averageGasPrice: ${averageGasPrice}`)

          await token.setVIP(deployer, false)

          const transactionResponse = await token.transfer(
            user1,
            tokensToSend
          )

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

          for (let j = 0; j < mineBlocks; j++) {
            await ethers.provider.send("evm_mine")
          }

          await expect(
            token.transfer(user1, tokensToSend, {
              gasPrice: bribe,
            })
          ).to.be.revertedWith(
            "token: Detected gas bribe, possible front-run"
          )
        })
      })

      describe("* Transfers *", () => {
        const halfToSend = ethers.utils.parseEther("0.5")

        it("Should transfer tokens successfully to an address", async () => {
          const startBalance = await token.balanceOf(user1)
          console.log(`startBalance: ${startBalance}`)

          await token.transfer(user1, tokensToSend)

          expect(await token.balanceOf(user1)).to.equal(tokensToSend)
          const endBalance = await token.balanceOf(user1)
          console.log(`endBalance: ${endBalance / 1e18}`)
        })

        it("Should prevent transfers over maxWallet", async () => {
          const maxWallet = await token.maxWallet()
          console.log(`maxWallet: ${maxWallet / 1e18}`)

          await expect(
            token.transfer(user1, maxWallet.add(1))
          ).to.be.revertedWith("token: Max wallet exceeded")
        })

        it("Should prevent 2 transfers in the same block", async () => {
          await token.transfer(user1, tokensToSend)

          await expect(
            token.transfer(user1, tokensToSend)
          ).to.be.revertedWith("token: Detected sandwich attack, BOT added")
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
          ).to.be.revertedWith(
            "token: Detected sandwich attack, mine more blocks"
          )
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
          playerToken = await ethers.getContract("token", user1)
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

          expect(await playerToken.balanceOf(user1)).to.equal(tokensToSpend)
          console.log(`Tokens approved from contract: ${tokensToSpend}`)
        })

        it("Should not allow unnaproved user to do transfers", async () => {
          await expect(
            playerToken.transferFrom(deployer, user1, tokensToSpend)
          ).to.be.revertedWith("ERC20: insufficient allowance")
        })

        it("Should not allow user to go over the allowance", async () => {
          await token.approve(user1, tokensToSpend)
          await expect(
            playerToken.transferFrom(deployer, user1, overDraft)
          ).to.be.revertedWith("ERC20: insufficient allowance")
        })

        it("Should emit approval event when an approval occurs", async () => {
          await expect(token.approve(user1, tokensToSpend)).to.emit(
            token,
            "Approval"
          )
        })
      })
    })
