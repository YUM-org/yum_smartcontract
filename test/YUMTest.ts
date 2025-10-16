import { expect } from "chai";
import { ethers } from "hardhat";
import { YUMFactory, YUMToken, AerodromeIntegration } from "../typechain-types";

describe("YUM.fun Contracts", function () {
  let yumFactory: YUMFactory;
  let aerodromeIntegration: AerodromeIntegration;
  let owner: any;
  let user1: any;
  let user2: any;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy AerodromeIntegration
    const AerodromeIntegration = await ethers.getContractFactory("AerodromeIntegration");
    aerodromeIntegration = await AerodromeIntegration.deploy();

    // Deploy YUMFactory
    const YUMFactory = await ethers.getContractFactory("YUMFactory");
    yumFactory = await YUMFactory.deploy(owner.address, owner.address);
    
    // Set Aerodrome integration in factory
    await yumFactory.setAerodromeIntegration(await aerodromeIntegration.getAddress());
  });

  describe("Token Creation", function () {
    it("Should create a token without first buy", async function () {
      const tx = await yumFactory.createToken(
        "Test Token",
        "TEST",
        "A test token for YUM.fun",
        "https://example.com/image.png",
        "https://twitter.com/test",
        "https://t.me/test",
        "https://test.com",
        false,
        0
      );

      await expect(tx)
        .to.emit(yumFactory, "TokenCreated");

      const tokenAddress = await yumFactory.allTokens(0);
      const token = await ethers.getContractAt("YUMToken", tokenAddress);
      
      expect(await token.name()).to.equal("Test Token");
      expect(await token.symbol()).to.equal("TEST");
      expect(await token.totalSupply()).to.equal(ethers.parseEther("1000000000")); // 1 billion tokens
    });

    it("Should create a token with first buy", async function () {
      const firstBuyAmount = ethers.parseEther("0.1");
      const totalPayment = firstBuyAmount + ethers.parseEther("0.02"); // 0.02 ETH first buy fee

      const tx = await yumFactory.connect(user1).createToken(
        "Test Token",
        "TEST",
        "A test token for YUM.fun",
        "https://example.com/image.png",
        "https://twitter.com/test",
        "https://t.me/test",
        "https://test.com",
        true,
        firstBuyAmount,
        { value: totalPayment }
      );

      await expect(tx)
        .to.emit(yumFactory, "TokenCreated")
        .and.to.emit(yumFactory, "FirstBuy");

      const tokenAddress = await yumFactory.allTokens(0);
      const token = await ethers.getContractAt("YUMToken", tokenAddress);
      
      expect(await token.totalEthRaised()).to.equal(firstBuyAmount);
      expect(await yumFactory.hasFirstBuy(tokenAddress)).to.be.true;
    });

    it("Should fail to create token with insufficient first buy amount", async function () {
      const firstBuyAmount = ethers.parseEther("0.01"); // Too low
      const totalPayment = firstBuyAmount + ethers.parseEther("0.02");

      await expect(
        yumFactory.connect(user1).createToken(
          "Test Token",
          "TEST",
          "A test token for YUM.fun",
          "https://example.com/image.png",
          "https://twitter.com/test",
          "https://t.me/test",
          "https://test.com",
          true,
          firstBuyAmount,
          { value: totalPayment }
        )
      ).to.be.revertedWith("First buy amount too low");
    });
  });

  describe("Trading", function () {
    let token: YUMToken;
    let tokenAddress: string;

    beforeEach(async function () {
      // Create a token with first buy
      const firstBuyAmount = ethers.parseEther("0.1");
      const totalPayment = firstBuyAmount + ethers.parseEther("0.02");

      await yumFactory.connect(user1).createToken(
        "Test Token",
        "TEST",
        "A test token for YUM.fun",
        "https://example.com/image.png",
        "https://twitter.com/test",
        "https://t.me/test",
        "https://test.com",
        true,
        firstBuyAmount,
        { value: totalPayment }
      );

      tokenAddress = await yumFactory.allTokens(0);
      token = await ethers.getContractAt("YUMToken", tokenAddress);
    });

    it("Should allow buying tokens", async function () {
      const buyAmount = ethers.parseEther("0.05");
      
      const tx = await yumFactory.connect(user2).buyTokens(tokenAddress, { value: buyAmount });
      
      await expect(tx)
        .to.emit(yumFactory, "Trade");

      const user2Balance = await token.balanceOf(user2.address);
      expect(user2Balance).to.be.gt(0);
    });

    it("Should allow selling tokens", async function () {
      const buyAmount = ethers.parseEther("0.05");
      
      // First buy some tokens
      await yumFactory.connect(user2).buyTokens(tokenAddress, { value: buyAmount });
      
      const user2Balance = await token.balanceOf(user2.address);
      const sellAmount = user2Balance / 2n; // Sell half
      
      const tx = await yumFactory.connect(user2).sellTokens(tokenAddress, sellAmount);
      
      await expect(tx)
        .to.emit(yumFactory, "Trade");
    });

    it("Should fail to trade before first buy", async function () {
      // Create a token without first buy
      await yumFactory.connect(user1).createToken(
        "Test Token 2",
        "TEST2",
        "A test token for YUM.fun",
        "https://example.com/image.png",
        "https://twitter.com/test",
        "https://t.me/test",
        "https://test.com",
        false,
        0
      );

      const tokenAddress2 = await yumFactory.allTokens(1);
      const buyAmount = ethers.parseEther("0.05");

      await expect(
        yumFactory.connect(user2).buyTokens(tokenAddress2, { value: buyAmount })
      ).to.be.revertedWith("First buy not made yet");
    });
  });

  describe("Graduation", function () {
    let token: YUMToken;
    let tokenAddress: string;

    beforeEach(async function () {
      // Create a token with first buy
      const firstBuyAmount = ethers.parseEther("0.1");
      const totalPayment = firstBuyAmount + ethers.parseEther("0.02");

      await yumFactory.connect(user1).createToken(
        "Test Token",
        "TEST",
        "A test token for YUM.fun",
        "https://example.com/image.png",
        "https://twitter.com/test",
        "https://t.me/test",
        "https://test.com",
        true,
        firstBuyAmount,
        { value: totalPayment }
      );

      tokenAddress = await yumFactory.allTokens(0);
      token = await ethers.getContractAt("YUMToken", tokenAddress);
    });

    it("Should graduate when threshold is reached", async function () {
      const graduationAmount = ethers.parseEther("4");
      const currentRaised = await token.totalEthRaised();
      
      // Calculate the amount needed including fees (0.1% total fees)
      const feeRate = 10n; // 0.1% in basis points
      const amountWithFees = (graduationAmount - currentRaised) * 10000n / (10000n - feeRate);
      
      // Aerodrome integration is already set up in beforeEach
      
      // Buy enough tokens to reach graduation threshold
      await yumFactory.connect(user2).buyTokens(tokenAddress, { value: amountWithFees });

      expect(await token.isGraduated()).to.be.true;
      expect(await token.graduationTime()).to.be.gt(0);
    });

    it("Should not graduate before threshold is reached", async function () {
      const buyAmount = ethers.parseEther("1");
      
      await yumFactory.connect(user2).buyTokens(tokenAddress, { value: buyAmount });

      expect(await token.isGraduated()).to.be.false;
      expect(await token.graduationTime()).to.equal(0);
    });
  });

  describe("Fee Structure", function () {
    it("Should collect correct fees", async function () {
      const firstBuyAmount = ethers.parseEther("0.1");
      const totalPayment = firstBuyAmount + ethers.parseEther("0.02");

      await yumFactory.connect(user1).createToken(
        "Test Token",
        "TEST",
        "A test token for YUM.fun",
        "https://example.com/image.png",
        "https://twitter.com/test",
        "https://t.me/test",
        "https://test.com",
        true,
        firstBuyAmount,
        { value: totalPayment }
      );

      const tokenAddress = await yumFactory.allTokens(0);
      const buyAmount = ethers.parseEther("0.1");
      
      const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);
      
      await yumFactory.connect(user2).buyTokens(tokenAddress, { value: buyAmount });
      
      const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);
      const feeReceived = ownerBalanceAfter - ownerBalanceBefore;
      
      // Should receive protocol fee (0.05% of buy amount)
      const expectedFee = buyAmount * 5n / 10000n;
      expect(feeReceived).to.be.closeTo(expectedFee, ethers.parseEther("0.001"));
    });
  });

  describe("Aerodrome Integration", function () {
    it("Should have correct Aerodrome addresses", async function () {
      // These are placeholder addresses for Base mainnet
      expect(await aerodromeIntegration.AERODROME_ROUTER()).to.equal("0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43");
      expect(await aerodromeIntegration.AERODROME_FACTORY()).to.equal("0x420DD381b31aEf6683db6B902084cB0FFECe40Da");
      expect(await aerodromeIntegration.WETH()).to.equal("0x4200000000000000000000000000000000000006");
    });

    it("Should allow owner to graduate token", async function () {
      const tokenAddress = "0x1234567890123456789012345678901234567890";
      const creator = user1.address;
      const ethAmount = ethers.parseEther("4");
      const tokenAmount = ethers.parseEther("207000000"); // 20.7% of 1 billion

      await expect(
        aerodromeIntegration.graduateToken(tokenAddress, creator, ethAmount, tokenAmount)
      ).to.emit(aerodromeIntegration, "TokenGraduated");
    });
  });
});
