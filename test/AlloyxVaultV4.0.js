const { expect } = require("chai")

describe("AlloyxVault V4.0 contract", function () {
  let alloyxTokenBronze
  let alloyxTokenSilver
  let vault
  let usdcCoin
  let gfiCoin
  let fiduCoin
  let goldFinchPoolToken
  let goldFinchDelegacy
  let seniorPool
  let tranchedPool
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
  const INITIAL_USDC_BALANCE = ethers.BigNumber.from(10).pow(6).mul(5)
  const INITIAL_GFI_BALANCE = ethers.BigNumber.from(10).pow(18).mul(5)
  const USDC_MANTISSA = ethers.BigNumber.from(10).pow(6)
  const ALLOY_MANTISSA = ethers.BigNumber.from(10).pow(18)

  before(async function () {
    [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9, ...addrs] =
      await ethers.getSigners()

    fiduCoin = await ethers.getContractFactory("FIDU")
    hardhatFiduCoin = await fiduCoin.deploy()
    gfiCoin = await ethers.getContractFactory("GFI")
    hardhatGfiCoin = await gfiCoin.deploy()
    usdcCoin = await ethers.getContractFactory("USDC")
    hardhatUsdcCoin = await usdcCoin.deploy()
    alloyxTokenBronze = await ethers.getContractFactory("AlloyxTokenBronze")
    hardhatAlloyxTokenBronze = await alloyxTokenBronze.deploy()
    alloyxTokenSilver = await ethers.getContractFactory("AlloyxTokenSilver")
    hardhatAlloyxTokenSilver = await alloyxTokenSilver.deploy()
    seniorPool = await ethers.getContractFactory("SeniorPool")
    hardhatSeniorPool = await seniorPool.deploy(3, hardhatFiduCoin.address, hardhatUsdcCoin.address)
    goldFinchPoolToken = await ethers.getContractFactory("PoolTokens")
    hardhatPoolTokens = await goldFinchPoolToken.deploy(hardhatSeniorPool.address)
    tranchedPool = await ethers.getContractFactory("TranchedPool")
    hardhatTranchedPool = await tranchedPool.deploy(
      hardhatPoolTokens.address,
      hardhatUsdcCoin.address
    )
    vault = await ethers.getContractFactory("AlloyxVaultV4_0")
    hardhatVault = await vault.deploy(
      hardhatAlloyxTokenBronze.address,
      hardhatAlloyxTokenSilver.address,
      hardhatUsdcCoin.address,
      owner.address
    )
    goldFinchDelegacy = await ethers.getContractFactory("GoldfinchDelegacy")
    hardhatGoldfinchDelegacy = await goldFinchDelegacy.deploy(
      hardhatUsdcCoin.address,
      hardhatFiduCoin.address,
      hardhatGfiCoin.address,
      hardhatPoolTokens.address,
      hardhatSeniorPool.address,
      hardhatVault.address
    )
    await hardhatPoolTokens.setPoolAddress(hardhatTranchedPool.address)

    await hardhatUsdcCoin.mint(hardhatVault.address, INITIAL_USDC_BALANCE)
    await hardhatGfiCoin.mint(hardhatGoldfinchDelegacy.address, INITIAL_GFI_BALANCE)
    await hardhatVault.changeGoldfinchDelegacyAddress(hardhatGoldfinchDelegacy.address)
    await hardhatAlloyxTokenBronze.transferOwnership(hardhatVault.address)
    await hardhatAlloyxTokenSilver.transferOwnership(hardhatVault.address)
    await hardhatFiduCoin.transferOwnership(hardhatSeniorPool.address)
    await hardhatVault.startVaultOperation()
  })

  describe("Basic Usecases", function () {
    it("Get Bronze Balance of Vault Upon start", async function () {
      const balance = await hardhatAlloyxTokenBronze.balanceOf(hardhatVault.address)
      expect(balance).to.equal(INITIAL_USDC_BALANCE.div(USDC_MANTISSA).mul(ALLOY_MANTISSA))
    })

    it("Mint pool tokens for vault", async function () {
      await hardhatPoolTokens.mint([100000, 999], hardhatGoldfinchDelegacy.address)
      await hardhatPoolTokens.mint([200000, 999], hardhatGoldfinchDelegacy.address)
      await hardhatPoolTokens.mint([300000, 999], hardhatGoldfinchDelegacy.address)
      await hardhatPoolTokens.mint([400000, 999], hardhatGoldfinchDelegacy.address)
      const balance = await hardhatPoolTokens.balanceOf(hardhatGoldfinchDelegacy.address)
      expect(balance).to.equal(4)
    })

    it("Get token value:getGoldfinchDelegacyBalanceInUSDC", async function () {
      const token1Value = await hardhatGoldfinchDelegacy.getJuniorTokenValue(1)
      const token2Value = await hardhatGoldfinchDelegacy.getJuniorTokenValue(2)
      const token3Value = await hardhatGoldfinchDelegacy.getJuniorTokenValue(3)
      const token4Value = await hardhatGoldfinchDelegacy.getJuniorTokenValue(4)
      const totalValue = await hardhatGoldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()
      expect(totalValue).to.equal(token1Value.add(token2Value).add(token3Value).add(token4Value))
    })

    it("Get total USDC value of vault:getAlloyxBronzeTokenBalanceInUSDC", async function () {
      const totalVaultValue = await hardhatVault.getAlloyxBronzeTokenBalanceInUSDC()
      const totalDelegacyValue = await hardhatGoldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()
      expect(totalVaultValue).to.equal(totalDelegacyValue.add(INITIAL_USDC_BALANCE))
    })

    it("Check the alloy token supply: alloyxBronzeToUSDC", async function () {
      const totalVaultValue = await hardhatVault.getAlloyxBronzeTokenBalanceInUSDC()
      const totalSupplyOfBronzeToken = await hardhatAlloyxTokenBronze.totalSupply()
      const expectedTotalVaultValue = await hardhatVault.alloyxBronzeToUSDC(
        totalSupplyOfBronzeToken
      )
      expect(expectedTotalVaultValue).to.equal(totalVaultValue)
    })

    it("Check the alloy token supply: USDCtoAlloyxBronze", async function () {
      const totalVaultValue = await hardhatVault.getAlloyxBronzeTokenBalanceInUSDC()
      const totalSupplyOfBronzeToken = await hardhatAlloyxTokenBronze.totalSupply()
      const expectedTotalSupplyOfBronzeToken = await hardhatVault.usdcToAlloyxBronze(
        totalVaultValue
      )
      expect(totalSupplyOfBronzeToken).to.equal(expectedTotalSupplyOfBronzeToken)
    })

    it("Deposit USDC tokens:depositUSDCCoin", async function () {
      await hardhatUsdcCoin.mint(addr1.address, ethers.BigNumber.from(10).pow(6).mul(5))
      const prevSupplyOfBronzeToken = await hardhatAlloyxTokenBronze.totalSupply()
      const usdcToDeposit = 5000000
      await hardhatUsdcCoin.connect(addr1).approve(hardhatVault.address, usdcToDeposit)
      await hardhatVault.connect(addr1).depositUSDCCoin(usdcToDeposit)
      const additionalBronzeMinted = await hardhatVault.usdcToAlloyxBronze(usdcToDeposit)
      const postSupplyOfBronzeToken = await hardhatAlloyxTokenBronze.totalSupply()
      expect(postSupplyOfBronzeToken).to.equal(additionalBronzeMinted.add(prevSupplyOfBronzeToken))
    })

    it("Deposit Alloy Bronze tokens:depositAlloyxBronzeTokens", async function () {
      const prevSupplyOfBronzeToken = await hardhatAlloyxTokenBronze.totalSupply()
      const alloyxBronzeToDeposit = ethers.BigNumber.from(10).pow(17)
      await hardhatAlloyxTokenBronze
        .connect(addr1)
        .approve(hardhatVault.address, alloyxBronzeToDeposit)
      await hardhatVault.connect(addr1).depositAlloyxBronzeTokens(alloyxBronzeToDeposit)
      const postSupplyOfBronzeToken = await hardhatAlloyxTokenBronze.totalSupply()
      expect(postSupplyOfBronzeToken).to.equal(prevSupplyOfBronzeToken.sub(alloyxBronzeToDeposit))
    })

    it("Deposit NFT tokens:depositNFTToken", async function () {
      const prevPoolTokenValue = await hardhatGoldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()
      const prevPoolTokenBalance = await hardhatPoolTokens.balanceOf(
        hardhatGoldfinchDelegacy.address
      )
      await hardhatPoolTokens.mint([400, 999], addr1.address)
      await hardhatUsdcCoin.mint(
        hardhatGoldfinchDelegacy.address,
        ethers.BigNumber.from(10).pow(6).mul(5)
      )
      const prevUSDC = await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const token5Value = await hardhatGoldfinchDelegacy.getJuniorTokenValue(5)
      await hardhatPoolTokens.connect(addr1).approve(hardhatVault.address, 5)
      await hardhatVault.connect(addr1).depositNFTToken(hardhatPoolTokens.address, 5)
      const postUSDC = await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const postPoolTokenValue = await hardhatGoldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()
      const postPoolTokenBalance = await hardhatPoolTokens.balanceOf(
        hardhatGoldfinchDelegacy.address
      )
      expect(prevUSDC.sub(postUSDC)).to.equal(token5Value)
      expect(postPoolTokenValue).to.equal(
        ethers.BigNumber.from(10).pow(6).mul(5).add(prevPoolTokenValue)
      )
      expect(postPoolTokenBalance).to.equal(prevPoolTokenBalance.add(1))
    })

    it("Purchase junior token:purchaseJuniorToken", async function () {
      const preBalance = await hardhatPoolTokens.balanceOf(hardhatGoldfinchDelegacy.address)
      const purchaseFee = 60000
      await hardhatVault.approveDelegacy(
        hardhatUsdcCoin.address,
        hardhatTranchedPool.address,
        purchaseFee
      )
      await hardhatVault.purchaseJuniorToken(purchaseFee, hardhatTranchedPool.address, purchaseFee)
      const postBalance = await hardhatPoolTokens.balanceOf(hardhatGoldfinchDelegacy.address)
      expect(postBalance).to.equal(preBalance.add(1))
    })

    it("Purchase senior token:purchaseSeniorTokens", async function () {
      const preBalance = await hardhatFiduCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const purchaseFee = 6000
      const shares = await hardhatSeniorPool.getNumShares(purchaseFee)
      await hardhatVault.approveDelegacy(
        hardhatUsdcCoin.address,
        hardhatSeniorPool.address,
        purchaseFee
      )
      await hardhatVault.purchaseSeniorTokens(purchaseFee)
      const postBalance = await hardhatFiduCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      expect(postBalance).to.equal(preBalance.add(shares))
    })

    it("Sell senior token:sellSeniorTokens", async function () {
      const preBalance = await hardhatFiduCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const preRepaymentFee = await hardhatGoldfinchDelegacy.repaymentFee()
      const preUsdcBalance = await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const sellUsdc = ethers.BigNumber.from(3000)
      const percentageBronzeRepayment = 2
      const shares = await hardhatSeniorPool.getNumShares(sellUsdc)
      await hardhatVault.sellSeniorTokens(shares)
      const postBalance = await hardhatFiduCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const postUsdcBalance = await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const postRepaymentFee = await hardhatGoldfinchDelegacy.repaymentFee()
      expect(preBalance.sub(postBalance)).to.equal(shares)
      expect(postUsdcBalance.sub(preUsdcBalance)).to.equal(sellUsdc)
      expect(postRepaymentFee.sub(preRepaymentFee)).to.equal(
        sellUsdc.mul(percentageBronzeRepayment).div(100)
      )
      await hardhatGoldfinchDelegacy.transferRepaymentFee(addr5.address)
      expect(await hardhatUsdcCoin.balanceOf(addr5.address)).to.equal(postRepaymentFee)
      expect(await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)).to.equal(
        postUsdcBalance.sub(postRepaymentFee)
      )
    })

    it("Sell junior token:sellJuniorTokens", async function () {
      const preRepaymentFee = await hardhatGoldfinchDelegacy.repaymentFee()
      const preUsdcBalance = await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const withdrawalAmount = ethers.BigNumber.from(500)
      const percentageBronzeRepayment = 2
      await hardhatVault.sellJuniorToken(1, withdrawalAmount, hardhatTranchedPool.address)
      const postUsdcBalance = await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const postRepaymentFee = await hardhatGoldfinchDelegacy.repaymentFee()
      expect(postUsdcBalance.sub(preUsdcBalance)).to.equal(withdrawalAmount)
      expect(postRepaymentFee.sub(preRepaymentFee)).to.equal(
        withdrawalAmount.mul(percentageBronzeRepayment).div(100)
      )
      await hardhatGoldfinchDelegacy.transferRepaymentFee(addr6.address)
      expect(await hardhatUsdcCoin.balanceOf(addr6.address)).to.equal(postRepaymentFee)
      expect(await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)).to.equal(
        postUsdcBalance.sub(postRepaymentFee)
      )
    })

    it("Migrate all PoolTokens:migrateAllGoldfinchPoolTokens", async function () {
      await hardhatVault.pause()
      const preVaultBalance = await hardhatPoolTokens.balanceOf(hardhatGoldfinchDelegacy.address)
      const preOwnerBalance = await hardhatPoolTokens.balanceOf(owner.address)
      await hardhatGoldfinchDelegacy.migrateAllGoldfinchPoolTokens(owner.address)
      const postVaultBalance = await hardhatPoolTokens.balanceOf(hardhatGoldfinchDelegacy.address)
      const postOwnerBalance = await hardhatPoolTokens.balanceOf(owner.address)
      expect(postOwnerBalance.sub(preOwnerBalance)).to.equal(preVaultBalance.sub(postVaultBalance))
      expect(postVaultBalance).to.equal(0)
    })

    it("Migrate all USDC:migrateERC20", async function () {
      const preVaultBalance = await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const preOwnerBalance = await hardhatUsdcCoin.balanceOf(owner.address)
      await hardhatGoldfinchDelegacy.migrateERC20(hardhatUsdcCoin.address, owner.address)
      const postVaultBalance = await hardhatUsdcCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      const postOwnerBalance = await hardhatUsdcCoin.balanceOf(owner.address)
      expect(postOwnerBalance.sub(preOwnerBalance)).to.equal(preVaultBalance.sub(postVaultBalance))
      expect(postVaultBalance).to.equal(0)
    })

    it("stake and unstake", async function () {
      await hardhatVault.unpause()
      await hardhatUsdcCoin.mint(addr3.address, ethers.BigNumber.from(10).pow(6).mul(5))
      const usdcToDeposit = 5000000
      const additionalBronzeMinted = await hardhatVault.usdcToAlloyxBronze(usdcToDeposit)
      await hardhatUsdcCoin.connect(addr3).approve(hardhatVault.address, usdcToDeposit)
      await hardhatVault.connect(addr3).depositUSDCCoin(usdcToDeposit)
      expect(await hardhatAlloyxTokenBronze.balanceOf(addr3.address)).to.equal(
        additionalBronzeMinted
      )
      await hardhatAlloyxTokenBronze
        .connect(addr3)
        .approve(hardhatVault.address, additionalBronzeMinted)
      const preVaultBronze = await hardhatAlloyxTokenBronze.balanceOf(hardhatVault.address)
      await hardhatVault.connect(addr3).stake(additionalBronzeMinted)
      const postVaultBronze = await hardhatAlloyxTokenBronze.balanceOf(hardhatVault.address)
      expect(await hardhatAlloyxTokenBronze.balanceOf(addr3.address)).to.equal(0)
      expect((await hardhatVault.stakeOf(addr3.address))[0]).to.equal(additionalBronzeMinted)
      expect(postVaultBronze.sub(preVaultBronze)).to.equal(additionalBronzeMinted)
      const halfAYear = (365 * 24 * 60 * 60) / 2
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const percentageRewardPerYear = 2
      const redeemable = await hardhatVault.connect(addr3).claimableSilverToken(addr3.address)
      expect(redeemable).to.equal(
        additionalBronzeMinted.mul(percentageRewardPerYear).div(100).div(2)
      )
      await hardhatVault.connect(addr3).unstake(additionalBronzeMinted.div(5))
      const postVaultBronze1 = await hardhatAlloyxTokenBronze.balanceOf(hardhatVault.address)
      expect(postVaultBronze.sub(postVaultBronze1)).to.equal(additionalBronzeMinted.div(5))
      expect(await hardhatAlloyxTokenBronze.balanceOf(addr3.address)).to.equal(
        additionalBronzeMinted.div(5)
      )
      await hardhatVault.connect(addr3).claimAlloyxSilver(redeemable.div(2))
      expect(await hardhatAlloyxTokenSilver.balanceOf(addr3.address)).to.equal(redeemable.div(2))
      const redeemable2 = await hardhatVault.connect(addr3).claimableSilverToken(addr3.address)
      expect(redeemable2.sub(redeemable.div(2)).div(redeemable2).mul(1000)).to.lt(1)
    })

    it("Transaction fee of percentageBronzeRedemption:depositAlloyxBronzeTokens", async function () {
      const prevSupplyOfBronzeToken = await hardhatAlloyxTokenBronze.totalSupply()
      const alloyxBronzeToDeposit = ethers.BigNumber.from(10).pow(17)
      const percentageBronzeRedemption = 1
      const expectedUSDC = await hardhatVault.alloyxBronzeToUSDC(alloyxBronzeToDeposit)
      const fee = expectedUSDC.mul(percentageBronzeRedemption).div(100)
      const preUsdcBalanceAddr1 = await hardhatUsdcCoin.balanceOf(addr1.address)
      const preUsdcBalanceVault = await hardhatUsdcCoin.balanceOf(hardhatVault.address)
      const preVaultFee = await hardhatVault.redemptionFee()
      await hardhatAlloyxTokenBronze
        .connect(addr1)
        .approve(hardhatVault.address, alloyxBronzeToDeposit)
      await hardhatVault.connect(addr1).depositAlloyxBronzeTokens(alloyxBronzeToDeposit)
      const postUsdcBalanceAddr1 = await hardhatUsdcCoin.balanceOf(addr1.address)
      const postUsdcBalanceVault = await hardhatUsdcCoin.balanceOf(hardhatVault.address)
      const postVaultFee = await hardhatVault.redemptionFee()
      const postSupplyOfBronzeToken = await hardhatAlloyxTokenBronze.totalSupply()
      expect(postSupplyOfBronzeToken).to.equal(prevSupplyOfBronzeToken.sub(alloyxBronzeToDeposit))
      expect(postUsdcBalanceAddr1.sub(preUsdcBalanceAddr1)).to.equal(expectedUSDC.sub(fee))
      expect(preUsdcBalanceVault.sub(postUsdcBalanceVault)).to.equal(expectedUSDC.sub(fee))
      expect(postVaultFee.sub(preVaultFee)).to.equal(fee)
      await hardhatVault.transferRedemptionFee(addr7.address)
      expect(await hardhatUsdcCoin.balanceOf(addr7.address)).to.equal(postVaultFee)
      expect(await hardhatUsdcCoin.balanceOf(hardhatVault.address)).to.equal(
        postUsdcBalanceVault.sub(postVaultFee)
      )
    })

    it("totalClaimableAndClaimedSilverToken", async function () {
      const claimable1 = await hardhatVault.claimableSilverToken(addr1.address)
      const claimable2 = await hardhatVault.claimableSilverToken(addr2.address)
      const claimable3 = await hardhatVault.claimableSilverToken(addr3.address)
      const claimableOwner = await hardhatVault.claimableSilverToken(owner.address)
      const totalClaimed = await hardhatAlloyxTokenSilver.totalSupply()
      const expectedTotal = await hardhatVault.totalClaimableAndClaimedSilverToken()
      expect(expectedTotal).to.equal(
        totalClaimed.add(claimableOwner).add(claimable1).add(claimable2).add(claimable3)
      )
    })

    it("Transaction fee of percentageSilverEarning:claimReward", async function () {
      const preEarningFee = await hardhatGoldfinchDelegacy.earningGfiFee()
      const preSilverBalance = await hardhatAlloyxTokenSilver.balanceOf(addr3.address)
      const preGfiBalance = await hardhatGfiCoin.balanceOf(addr3.address)
      const amountToRewardToClaim = preSilverBalance.div(3)
      const totalClaimedAndClaimable = await hardhatVault.totalClaimableAndClaimedSilverToken()
      const gfiBalance = await hardhatGoldfinchDelegacy.getGFIBalance()
      const percentageEarningFee = 10
      const totalRewardToProcess = amountToRewardToClaim
        .mul(gfiBalance.sub(preEarningFee))
        .div(totalClaimedAndClaimable)
      const earningFee = totalRewardToProcess.mul(percentageEarningFee).div(100)
      await hardhatVault.connect(addr3).claimReward(amountToRewardToClaim)
      const postEarningFee = await hardhatGoldfinchDelegacy.earningGfiFee()
      const postSilverBalance = await hardhatAlloyxTokenSilver.balanceOf(addr3.address)
      const postGfiBalance = await hardhatGfiCoin.balanceOf(addr3.address)
      const postGfiBalanceOfDelegacy = await hardhatGfiCoin.balanceOf(
        hardhatGoldfinchDelegacy.address
      )
      expect(preSilverBalance.sub(postSilverBalance)).to.equal(amountToRewardToClaim)
      expect(postEarningFee.sub(preEarningFee)).to.equal(earningFee)
      expect(postGfiBalance.sub(preGfiBalance)).to.equal(totalRewardToProcess.sub(earningFee))
      await hardhatGoldfinchDelegacy.transferEarningGfiFee(addr8.address)
      expect(await hardhatGfiCoin.balanceOf(addr8.address)).to.equal(postEarningFee)
      expect(await hardhatGfiCoin.balanceOf(hardhatGoldfinchDelegacy.address)).to.equal(
        postGfiBalanceOfDelegacy.sub(postEarningFee)
      )
    })

    it("stake and unstake many times", async function () {
      await hardhatUsdcCoin.mint(addr9.address, ethers.BigNumber.from(10).pow(10).mul(5))
      const preUsdcBalanceAddr9 = await hardhatUsdcCoin.balanceOf(addr9.address)
      const usdcToDeposit = 1000000000
      const additionalBronzeMinted = await hardhatVault.usdcToAlloyxBronze(usdcToDeposit)
      await hardhatUsdcCoin.connect(addr9).approve(hardhatVault.address, usdcToDeposit)
      const preAlloyBronzeBalanceVault = await hardhatAlloyxTokenBronze.balanceOf(
        hardhatVault.address
      )
      await hardhatVault.connect(addr9).depositUSDCCoinWithStake(usdcToDeposit)
      const postUsdcBalanceAddr9 = await hardhatUsdcCoin.balanceOf(addr9.address)
      const postAlloyBronzeBalanceVault = await hardhatAlloyxTokenBronze.balanceOf(
        hardhatVault.address
      )
      expect(postAlloyBronzeBalanceVault.sub(preAlloyBronzeBalanceVault)).to.equal(
        additionalBronzeMinted
      )
      expect(preUsdcBalanceAddr9.sub(postUsdcBalanceAddr9)).to.equal(usdcToDeposit)
      const fiftyYears = 365 * 24 * 60 * 60 * 50
      await ethers.provider.send("evm_increaseTime", [fiftyYears])
      await ethers.provider.send("evm_mine")
      const percentageRewardPerYear = 2
      const redeemable = await hardhatVault.claimableSilverToken(addr9.address)
      expect(redeemable).to.equal(
        additionalBronzeMinted.mul(percentageRewardPerYear).mul(50).div(100)
      )
      await hardhatVault.connect(addr9).unstake(additionalBronzeMinted.div(8))
      const postBronzeBalanceAddr9 = await hardhatAlloyxTokenBronze.balanceOf(addr9.address)
      expect(postBronzeBalanceAddr9).to.equal(additionalBronzeMinted.div(8))
      await hardhatVault.connect(addr9).unstake(additionalBronzeMinted.div(4))
      const postBronzeBalanceAddr9_2 = await hardhatAlloyxTokenBronze.balanceOf(addr9.address)
      expect(postBronzeBalanceAddr9_2).to.equal(
        additionalBronzeMinted.div(4).add(additionalBronzeMinted.div(8))
      )
      const redeemable2 = await hardhatVault.claimableSilverToken(addr9.address)
      const twentyYears = 365 * 24 * 60 * 60 * 20
      await ethers.provider.send("evm_increaseTime", [twentyYears])
      await ethers.provider.send("evm_mine")
      const redeemable3 = await hardhatVault.claimableSilverToken(addr9.address)
      const stakedAmount = additionalBronzeMinted.sub(
        additionalBronzeMinted.div(4).add(additionalBronzeMinted.div(8))
      )
      expect(redeemable3.sub(redeemable2)).to.equal(
        stakedAmount.mul(percentageRewardPerYear).mul(20).div(100)
      )
      await hardhatAlloyxTokenBronze
        .connect(addr9)
        .approve(hardhatVault.address, additionalBronzeMinted.div(10))
      await hardhatVault.connect(addr9).stake(additionalBronzeMinted.div(10))
      const redeemable4 = await hardhatVault.claimableSilverToken(addr9.address)
      const tenYears = 365 * 24 * 60 * 60 * 10
      await ethers.provider.send("evm_increaseTime", [tenYears])
      await ethers.provider.send("evm_mine")
      const redeemable5 = await hardhatVault.claimableSilverToken(addr9.address)
      expect(redeemable5.sub(redeemable4)).to.equal(
        stakedAmount
          .add(additionalBronzeMinted.div(10))
          .mul(percentageRewardPerYear)
          .mul(10)
          .div(100)
      )
      await hardhatAlloyxTokenBronze
        .connect(addr9)
        .approve(hardhatVault.address, additionalBronzeMinted.div(20))
      await hardhatVault.connect(addr9).stake(additionalBronzeMinted.div(20))
      const fiveYears = 365 * 24 * 60 * 60 * 5
      const redeemable6 = await hardhatVault.claimableSilverToken(addr9.address)
      await ethers.provider.send("evm_increaseTime", [fiveYears])
      await ethers.provider.send("evm_mine")
      const redeemable7 = await hardhatVault.claimableSilverToken(addr9.address)
      expect(redeemable7.sub(redeemable6)).to.equal(
        stakedAmount
          .add(additionalBronzeMinted.div(10))
          .add(additionalBronzeMinted.div(20))
          .mul(percentageRewardPerYear)
          .mul(5)
          .div(100)
      )
    })
  })
})
