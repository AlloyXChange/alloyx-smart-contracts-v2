const { expect } = require("chai")

describe("AlloyxVault V2.0 contract", function () {
  let alloyxTokenDURA
  let vault
  let usdcCoin
  let gfiCoin
  let fiduCoin
  let goldFinchPoolToken
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
    alloyxTokenDURA = await ethers.getContractFactory("AlloyxTokenDURA")
    hardhatAlloyxTokenDURA = await alloyxTokenDURA.deploy()
    seniorPool = await ethers.getContractFactory("SeniorPool")
    hardhatSeniorPool = await seniorPool.deploy(3, hardhatFiduCoin.address, hardhatUsdcCoin.address)
    goldFinchPoolToken = await ethers.getContractFactory("PoolTokens")
    hardhatPoolTokens = await goldFinchPoolToken.deploy(hardhatSeniorPool.address)
    tranchedPool = await ethers.getContractFactory("TranchedPool")
    hardhatTranchedPool = await tranchedPool.deploy(
      hardhatPoolTokens.address,
      hardhatUsdcCoin.address
    )
    await hardhatPoolTokens.setPoolAddress(hardhatTranchedPool.address)
    vault = await ethers.getContractFactory("AlloyxVaultV2_0")
    hardhatVault = await vault.deploy(
      hardhatAlloyxTokenDURA.address,
      hardhatUsdcCoin.address,
      hardhatFiduCoin.address,
      hardhatGfiCoin.address,
      hardhatPoolTokens.address,
      hardhatSeniorPool.address
    )

    await hardhatUsdcCoin.mint(hardhatVault.address, INITIAL_USDC_BALANCE)
    await hardhatAlloyxTokenDURA.transferOwnership(hardhatVault.address)
    await hardhatFiduCoin.transferOwnership(hardhatSeniorPool.address)
    await hardhatVault.startVaultOperation()
  })

  describe("Basic Usecases", function () {
    it("Get DURA Balance of Vault Upon start", async function () {
      const balance = await hardhatAlloyxTokenDURA.balanceOf(hardhatVault.address)
      expect(balance).to.equal(INITIAL_USDC_BALANCE.div(USDC_MANTISSA).mul(ALLOY_MANTISSA))
    })

    it("Mint pool tokens for vault", async function () {
      await hardhatPoolTokens.mint([100000, 999], hardhatVault.address)
      await hardhatPoolTokens.mint([200000, 999], hardhatVault.address)
      await hardhatPoolTokens.mint([300000, 999], hardhatVault.address)
      await hardhatPoolTokens.mint([400000, 999], hardhatVault.address)
      const balance = await hardhatPoolTokens.balanceOf(hardhatVault.address)
      expect(balance).to.equal(4)
    })

    it("Get token value:getGoldFinchPoolTokenBalanceInUSDC", async function () {
      const token1Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 1)
      const token2Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 2)
      const token3Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 3)
      const token4Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 4)
      const totalValue = await hardhatVault.getGoldFinchPoolTokenBalanceInUSDC()
      expect(totalValue).to.equal(token1Value.add(token2Value).add(token3Value).add(token4Value))
    })

    it("Get total USDC value of vault:getAlloyxDURATokenBalanceInUSDC", async function () {
      const token1Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 1)
      const token2Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 2)
      const token3Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 3)
      const token4Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 4)
      const totalVaultValue = await hardhatVault.getAlloyxDURATokenBalanceInUSDC()
      expect(totalVaultValue).to.equal(
        token1Value.add(token2Value).add(token3Value).add(token4Value).add(INITIAL_USDC_BALANCE)
      )
    })

    it("Check the alloy token supply: alloyxDURAToUSDC", async function () {
      const totalVaultValue = await hardhatVault.getAlloyxDURATokenBalanceInUSDC()
      const totalSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const expectedTotalVaultValue = await hardhatVault.alloyxDURAToUSDC(totalSupplyOfDURAToken)
      expect(expectedTotalVaultValue).to.equal(totalVaultValue)
    })

    it("Check the alloy token supply: USDCtoAlloyxDURA", async function () {
      const totalVaultValue = await hardhatVault.getAlloyxDURATokenBalanceInUSDC()
      const totalSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const expectedTotalSupplyOfDURAToken = await hardhatVault.USDCtoAlloyxDURA(totalVaultValue)
      expect(totalSupplyOfDURAToken).to.equal(expectedTotalSupplyOfDURAToken)
    })

    it("Deposit USDC tokens:depositUSDCCoin", async function () {
      await hardhatUsdcCoin.mint(addr1.address, ethers.BigNumber.from(10).pow(6).mul(5))
      const prevSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const usdcToDeposit = 5000000
      await hardhatUsdcCoin.connect(addr1).approve(hardhatVault.address, usdcToDeposit)
      await hardhatVault.connect(addr1).depositUSDCCoin(usdcToDeposit)
      const additionalDURAMinted = await hardhatVault.USDCtoAlloyxDURA(usdcToDeposit)
      const postSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      expect(postSupplyOfDURAToken).to.equal(additionalDURAMinted.add(prevSupplyOfDURAToken))
    })

    it("Deposit Alloy DURA tokens:depositAlloyxDURATokens", async function () {
      const prevSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const alloyxDURAToDeposit = 5000000000000000
      const value = await hardhatVault.alloyxDURAToUSDC(alloyxDURAToDeposit)
      await hardhatAlloyxTokenDURA.connect(addr1).approve(hardhatVault.address, alloyxDURAToDeposit)
      await hardhatVault.connect(addr1).depositAlloyxDURATokens(alloyxDURAToDeposit)
      const postSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      expect(postSupplyOfDURAToken).to.equal(prevSupplyOfDURAToken.sub(alloyxDURAToDeposit))
    })

    it("Deposit NFT tokens:depositNFTToken", async function () {
      const prevPoolTokenValue = await hardhatVault.getGoldFinchPoolTokenBalanceInUSDC()
      await hardhatPoolTokens.mint([600000, 999], addr1.address)
      const token5Value = await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address, 5)
      await hardhatPoolTokens.connect(addr1).approve(hardhatVault.address, 5)
      await hardhatVault.connect(addr1).depositNFTToken(hardhatPoolTokens.address, 5)
      const postPoolTokenValue = await hardhatVault.getGoldFinchPoolTokenBalanceInUSDC()
      expect(postPoolTokenValue).to.equal(token5Value.add(prevPoolTokenValue))
    })

    it("Purchase junior token:purchaseJuniorToken", async function () {
      const preBalance = await hardhatPoolTokens.balanceOf(hardhatVault.address)
      const purchaseFee = 60
      await hardhatVault.approve(hardhatUsdcCoin.address, hardhatTranchedPool.address, purchaseFee)
      await hardhatVault.purchaseJuniorToken(purchaseFee, hardhatTranchedPool.address, 1)
      const postBalance = await hardhatPoolTokens.balanceOf(hardhatVault.address)
      expect(postBalance).to.equal(preBalance.add(1))
    })

    it("Purchase senior token:purchaseSeniorTokens", async function () {
      const preBalance = await hardhatFiduCoin.balanceOf(hardhatVault.address)
      const purchaseFee = 6000
      const shares = await hardhatSeniorPool.getNumShares(purchaseFee)
      await hardhatVault.approve(hardhatUsdcCoin.address, hardhatSeniorPool.address, purchaseFee)
      await hardhatVault.purchaseSeniorTokens(purchaseFee, hardhatSeniorPool.address)
      const postBalance = await hardhatFiduCoin.balanceOf(hardhatVault.address)
      expect(postBalance).to.equal(preBalance.add(shares))
    })

    it("Migrate all PoolTokens:migrateAllGoldfinchPoolTokens", async function () {
      await hardhatVault.pause()
      const preVaultBalance = await hardhatPoolTokens.balanceOf(hardhatVault.address)
      const preOwnerBalance = await hardhatPoolTokens.balanceOf(owner.address)
      await hardhatVault.migrateAllGoldfinchPoolTokens(owner.address)
      const postVaultBalance = await hardhatPoolTokens.balanceOf(hardhatVault.address)
      const postOwnerBalance = await hardhatPoolTokens.balanceOf(owner.address)
      expect(postOwnerBalance.sub(preOwnerBalance)).to.equal(preVaultBalance.sub(postVaultBalance))
      expect(postVaultBalance).to.equal(0)
    })

    it("Migrate all USDC:migrateERC20", async function () {
      const preVaultBalance = await hardhatUsdcCoin.balanceOf(hardhatVault.address)
      const preOwnerBalance = await hardhatUsdcCoin.balanceOf(owner.address)
      await hardhatVault.migrateERC20(hardhatUsdcCoin.address, owner.address)
      const postVaultBalance = await hardhatUsdcCoin.balanceOf(hardhatVault.address)
      const postOwnerBalance = await hardhatUsdcCoin.balanceOf(owner.address)
      expect(postOwnerBalance.sub(preOwnerBalance)).to.equal(preVaultBalance.sub(postVaultBalance))
      expect(postVaultBalance).to.equal(0)
    })
  })
})
