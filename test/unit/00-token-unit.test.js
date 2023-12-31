const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("XMEV2 Token Contract", function () {
  let XMEV2, xmev2, devWallet, addr1, addr2, addrs;

  beforeEach(async function () {
    XMEV2 = await ethers.getContractFactory("XMEV2");
    [devWallet, addr1, addr2, ...addrs] = await ethers.getSigners();
    xmev2 = await XMEV2.deploy(devWallet.address, addr2.address);
    await xmev2.deployed();
  });

  it("Should transfer 1% tax to devWallet on transfer", async function () {
    // Open trading
    await xmev2.openTrading();

    // Transfer some tokens from addr1 to addr2
    const transferAmount = ethers.utils.parseEther("100");
    await xmev2.connect(addr1).transfer(addr2.address, transferAmount);

    // Calculate the expected tax amount
    const expectedTax = transferAmount.div(100);

    // Get the devWallet balance
    const devWalletBalance = await xmev2.balanceOf(devWallet.address);

    // Check if the devWallet balance is equal to the expected tax
    expect(devWalletBalance).to.equal(expectedTax);
  });
});