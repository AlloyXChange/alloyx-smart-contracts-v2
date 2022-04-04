const { expect } = require("chai")

describe("AlloyxVault V2.1 contract", function () {
  let alloyxTokenBronze
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
  let addrs
  const INITIAL_USDC_BALANCE = ethers.BigNumber.from(10).pow(6).mul(5)
  const USDC_MANTISSA = ethers.BigNumber.from(10).pow(6)
  const ALLOY_MANTISSA = ethers.BigNumber.from(10).pow(18)

  before(async function () {
    ;[owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    fiduCoin = await ethers.getContractFactory("FIDU")
    hardhatFiduCoin = await fiduCoin.deploy()
    gfiCoin = await ethers.getContractFactory("GFI")
    hardhatGfiCoin = await gfiCoin.deploy()
    usdcCoin = await ethers.getContractFactory("USDC")
    hardhatUsdcCoin = await usdcCoin.deploy()
    alloyxTokenBronze = await ethers.getContractFactory("AlloyxTokenBronze")
    hardhatAlloyxTokenBronze = await alloyxTokenBronze.deploy()
    seniorPool = await ethers.getContractFactory("SeniorPool")
    hardhatSeniorPool = await seniorPool.deploy(3, hardhatFiduCoin.address, hardhatUsdcCoin.address)
    goldFinchPoolToken = await ethers.getContractFactory("PoolTokens")
    hardhatPoolTokens = await goldFinchPoolToken.deploy(hardhatSeniorPool.address)
    tranchedPool = await ethers.getContractFactory("TranchedPool")
    hardhatTranchedPool = await tranchedPool.deploy(
      hardhatPoolTokens.address,
      hardhatUsdcCoin.address
    )
    vault = await ethers.getContractFactory("AlloyxVaultV2_1")
    hardhatVault = await vault.deploy(
      hardhatAlloyxTokenBronze.address,
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
    await hardhatVault.changeGoldfinchDelegacyAddress(hardhatGoldfinchDelegacy.address)
    await hardhatAlloyxTokenBronze.transferOwnership(hardhatVault.address)
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
      const expectedTotalSupplyOfBronzeToken = await hardhatVault.USDCtoAlloyxBronze(
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
      const additionalBronzeMinted = await hardhatVault.USDCtoAlloyxBronze(usdcToDeposit)
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
      const purchaseFee = 60
      await hardhatVault.approveDelegacy(
        hardhatUsdcCoin.address,
        hardhatTranchedPool.address,
        purchaseFee
      )
      await hardhatVault.purchaseJuniorToken(purchaseFee, hardhatTranchedPool.address, 1)
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
      await hardhatVault.purchaseSeniorTokens(purchaseFee, hardhatSeniorPool.address)
      const postBalance = await hardhatFiduCoin.balanceOf(hardhatGoldfinchDelegacy.address)
      expect(postBalance).to.equal(preBalance.add(shares))
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
  })
})
