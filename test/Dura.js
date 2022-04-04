const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("Dura contract", function () {
  let dura
  let crown
  let owner
  let addr1
  let addr2
  let addr3
  let addr4
  let addr5
  let addr6
  let addr7
  let addr8
  let addr9
  let addrs

  before(async function () {
    [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9, ...addrs] =
      await ethers.getSigners()
    crown = await ethers.getContractFactory("Crown")
    hardhatCrown = await crown.deploy()
    dura = await ethers.getContractFactory("Dura")
    hardhatDura = await dura.deploy(hardhatCrown.address)
    await hardhatCrown.transferOwnership(hardhatDura.address)
  })

  describe("Base usecases", function () {
    it("mint", async function () {
      const mintAmount = 5000000
      await hardhatDura.mint(owner.address, mintAmount)
      expect(await hardhatDura.balanceOf(owner.address)).to.be.equal(mintAmount)
      expect(await hardhatCrown.balanceOf(hardhatDura.address)).to.be.equal(mintAmount)
      expect(await hardhatDura.crownCap(owner.address)).to.be.equal(mintAmount)
    })

    it("mintAndStake", async function () {
      const mintAndStakeAmount = 5000000
      await hardhatDura.mint(addr1.address, mintAndStakeAmount)
      await hardhatDura.mintAndStake(addr1.address, mintAndStakeAmount)
      expect(await hardhatCrown.balanceOf(hardhatDura.address)).to.be.equal(mintAndStakeAmount * 3)
      expect(await hardhatDura.crownCap(addr1.address)).to.be.equal(mintAndStakeAmount * 2)
      const redeemableNow = await hardhatDura.redeemableCrown(addr1.address)
      expect(redeemableNow).to.be.equal(0)
      const halfAYear = (365 * 24 * 60 * 60) / 2
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const redeemableHalfYearLater = await hardhatDura.redeemableCrown(addr1.address)
      expect(redeemableHalfYearLater).to.be.equal(mintAndStakeAmount / 2)

      const mintAndStakeAmountMore = 1000000
      await hardhatDura.mintAndStake(addr1.address, mintAndStakeAmountMore)
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const redeemableOneYearLater = await hardhatDura.redeemableCrown(addr1.address)
      expect(redeemableOneYearLater).to.be.equal(mintAndStakeAmount + mintAndStakeAmountMore / 2)

      const mintAndStakeAmountAgain = 100000
      await hardhatDura.unstake(addr1.address, mintAndStakeAmount + mintAndStakeAmountMore)
      await hardhatDura.mint(addr1.address, mintAndStakeAmountAgain)
      await hardhatDura.stake(addr1.address, mintAndStakeAmountAgain)
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const redeemableOneAndHalfYearLater = await hardhatDura.redeemableCrown(addr1.address)
      expect(redeemableOneAndHalfYearLater).to.be.equal(
        mintAndStakeAmount + mintAndStakeAmountMore / 2 + mintAndStakeAmountAgain / 2
      )
    })

    it("mint and burn", async function () {
      const mintAndStakeAmount = 5000000
      await hardhatDura.mint(addr3.address, mintAndStakeAmount)
      await hardhatDura.mintAndStake(addr3.address, mintAndStakeAmount)
      expect(await hardhatDura.crownCap(addr3.address)).to.be.equal(mintAndStakeAmount * 2)
      const redeemableNow = await hardhatDura.redeemableCrown(addr3.address)
      expect(redeemableNow).to.be.equal(0)

      const halfAYear = (365 * 24 * 60 * 60) / 2
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const redeemableHalfYearLater = await hardhatDura.redeemableCrown(addr3.address)
      expect(redeemableHalfYearLater).to.be.equal(mintAndStakeAmount / 2)

      await hardhatDura.unstake(addr3.address, mintAndStakeAmount)

      await hardhatDura.burn(addr3.address, mintAndStakeAmount / 4)
      expect(await hardhatDura.crownCap(addr3.address)).to.be.equal((7 * mintAndStakeAmount) / 4)

      await hardhatDura.burn(addr3.address, (3 * mintAndStakeAmount) / 2)
      expect(await hardhatDura.crownCap(addr3.address)).to.be.equal(mintAndStakeAmount / 2)
    })

    it("stake and unstake", async function () {
      const initBalance = 40000
      await hardhatDura.mint(addr4.address, initBalance)
      const amount1 = 10000
      await hardhatDura.stake(addr4.address, amount1)

      const quarterYear = (365 * 24 * 60 * 60) / 4
      await ethers.provider.send("evm_increaseTime", [quarterYear])
      await ethers.provider.send("evm_mine")
      const redeemable1 = await hardhatDura.redeemableCrown(addr4.address)
      expect(redeemable1).to.be.equal(amount1 / 4)

      const amount2 = 20000
      const quarterHalfYear = (365 * 24 * 60 * 60) / 8
      await hardhatDura.stake(addr4.address, amount2)
      await ethers.provider.send("evm_increaseTime", [quarterHalfYear])
      await ethers.provider.send("evm_mine")
      const redeemable2 = await hardhatDura.redeemableCrown(addr4.address)
      expect(redeemable2).to.be.equal(amount1 / 4 + amount1 / 8 + amount2 / 8)

      await hardhatDura.unstake(addr4.address, amount1)
      await ethers.provider.send("evm_increaseTime", [quarterHalfYear])
      await ethers.provider.send("evm_mine")
      const redeemable3 = await hardhatDura.redeemableCrown(addr4.address)
      expect(redeemable3).to.be.equal(amount1 / 4 + amount1 / 8 + amount2 / 8 + amount2 / 8)

      await hardhatDura.unstake(addr4.address, amount2)
      const cap1 = await hardhatDura.crownCap(addr4.address)
      expect(cap1).to.be.equal(initBalance)
      await hardhatDura.burn(addr4.address, initBalance)
      const cap2 = await hardhatDura.crownCap(addr4.address)
      const redeemable4 = await hardhatDura.redeemableCrown(addr4.address)
      expect(redeemable4).to.be.equal(amount1 / 4 + amount1 / 8 + amount2 / 8 + amount2 / 8)
      expect(cap2).to.be.equal(amount1 / 4 + amount1 / 8 + amount2 / 8 + amount2 / 8)
    })

    it("transfer", async function () {
      const initBalance = 40000
      await hardhatDura.mint(addr5.address, initBalance)
      const amount1 = 10000
      await hardhatDura.connect(addr5).transfer(addr6.address, amount1)
      const cap5 = await hardhatDura.crownCap(addr5.address)
      expect(cap5).to.be.equal(initBalance - amount1)
      const cap6 = await hardhatDura.crownCap(addr6.address)
      expect(cap6).to.be.equal(amount1)

      await hardhatDura.stake(addr5.address, initBalance - amount1)
      const halfAYear = (365 * 24 * 60 * 60) / 2
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const amount2 = 20000
      await hardhatDura.unstake(addr5.address, initBalance - amount1)
      await hardhatDura.connect(addr5).transfer(addr6.address, amount2)
      const redeemable5 = await hardhatDura.redeemableCrown(addr5.address)
      expect(redeemable5).to.be.equal((initBalance - amount1) / 2)
      const cap5_new = await hardhatDura.crownCap(addr5.address)
      expect(cap5_new).to.be.equal(redeemable5)
      const cap6_new = await hardhatDura.crownCap(addr6.address)
      expect(cap6_new).to.be.equal(initBalance - cap5_new)
    })

    it("transferFrom", async function () {
      const initBalance = 40000
      await hardhatDura.mint(addr7.address, initBalance)
      const amount1 = 10000
      await hardhatDura.connect(addr7).approve(owner.address, amount1)
      await hardhatDura.transferFrom(addr7.address, addr8.address, amount1)
      const cap7 = await hardhatDura.crownCap(addr7.address)
      expect(cap7).to.be.equal(initBalance - amount1)
      const cap8 = await hardhatDura.crownCap(addr8.address)
      expect(cap8).to.be.equal(amount1)

      await hardhatDura.stake(addr7.address, initBalance - amount1)
      const halfAYear = (365 * 24 * 60 * 60) / 2
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const amount2 = 20000
      await hardhatDura.unstake(addr7.address, initBalance - amount1)
      await hardhatDura.connect(addr7).approve(owner.address, amount2)
      await hardhatDura.transferFrom(addr7.address, addr8.address, amount2)
      const redeemable7 = await hardhatDura.redeemableCrown(addr7.address)
      expect(redeemable7).to.be.equal((initBalance - amount1) / 2)
      const cap7_new = await hardhatDura.crownCap(addr7.address)
      expect(cap7_new).to.be.equal(redeemable7)
      const cap8_new = await hardhatDura.crownCap(addr8.address)
      expect(cap8_new).to.be.equal(initBalance - cap7_new)
    })

    it("redeemCrown and redeemAllCrown", async function () {
      const mintAndStakeAmount = 5000000
      await hardhatDura.mint(addr9.address, mintAndStakeAmount)
      await hardhatDura.mintAndStake(addr9.address, mintAndStakeAmount)
      expect(await hardhatDura.crownCap(addr9.address)).to.be.equal(mintAndStakeAmount * 2)
      const redeemableNow = await hardhatDura.redeemableCrown(addr9.address)
      expect(redeemableNow).to.be.equal(0)

      const halfAYear = (365 * 24 * 60 * 60) / 2
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const redeemableHalfYearLater = await hardhatDura.redeemableCrown(addr9.address)
      const capBefore = await hardhatDura.crownCap(addr9.address)
      expect(redeemableHalfYearLater).to.be.equal(mintAndStakeAmount / 2)
      await hardhatDura.redeemCrown(addr9.address, redeemableHalfYearLater / 2)
      const capAfter = await hardhatDura.crownCap(addr9.address)
      expect(await hardhatCrown.balanceOf(addr9.address)).to.be.equal(redeemableHalfYearLater / 2)
      expect(capBefore.sub(capAfter)).to.be.equal(redeemableHalfYearLater / 2)
      const redeemableAfterRedeem = await hardhatDura.redeemableCrown(addr9.address)
      expect(redeemableAfterRedeem).to.be.equal(redeemableHalfYearLater / 2)

      await hardhatDura.redeemAllCrown(addr9.address)
      const redeemableAfterRedeem2 = await hardhatDura.redeemableCrown(addr9.address)
      expect(redeemableAfterRedeem2).to.be.equal(0)
      expect(await hardhatDura.crownCap(addr9.address)).to.be.equal(
        capAfter.sub(redeemableAfterRedeem)
      )
      expect(await hardhatCrown.balanceOf(addr9.address)).to.be.equal(redeemableHalfYearLater)
    })
  })
})
