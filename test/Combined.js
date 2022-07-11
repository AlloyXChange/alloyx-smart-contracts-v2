const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")
describe("Combined Testcases", function () {
  let alloyxTokenDURA
  let alloyxTokenCRWN
  let treasury
  let exchange
  let alloyxConfig
  let usdcCoin
  let gfiCoin
  let fiduCoin
  let stableCoinDesk
  let stakeDesk
  let goldfinchDesk
  let goldFinchPoolToken
  let sortedGoldfinchTranches
  let alloyxStakeInfo
  let alloyxWhitelist
  let seniorPool
  let tranchedPool
  let uidERC1155
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
    ;[owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9, ...addrs] =
      await ethers.getSigners()

    fiduCoin = await ethers.getContractFactory("FIDU")
    hardhatFiduCoin = await fiduCoin.deploy()
    gfiCoin = await ethers.getContractFactory("GFI")
    hardhatGfiCoin = await gfiCoin.deploy()
    usdcCoin = await ethers.getContractFactory("USDC")
    hardhatUsdcCoin = await usdcCoin.deploy()
    alloyxConfig = await ethers.getContractFactory("AlloyxConfig")
    hardhatAlloyxConfig = await upgrades.deployProxy(alloyxConfig, [])
    await hardhatAlloyxConfig.deployed()
    alloyxStakeInfo = await ethers.getContractFactory("AlloyxStakeInfo")
    hardhatAlloyxStakeInfo = await upgrades.deployProxy(alloyxStakeInfo, [
      hardhatAlloyxConfig.address,
    ])
    alloyxTokenDURA = await ethers.getContractFactory("AlloyxTokenDURA")
    hardhatAlloyxTokenDURA = await upgrades.deployProxy(alloyxTokenDURA, [])
    await hardhatAlloyxTokenDURA.deployed()
    alloyxTokenCRWN = await ethers.getContractFactory("AlloyxTokenCRWN")
    hardhatAlloyxTokenCRWN = await upgrades.deployProxy(alloyxTokenCRWN, [])
    await hardhatAlloyxTokenCRWN.deployed()
    goldfinchDesk = await ethers.getContractFactory("GoldfinchDesk")
    hardhatGoldfinchDesk = await upgrades.deployProxy(goldfinchDesk, [hardhatAlloyxConfig.address])
    await hardhatGoldfinchDesk.deployed()
    stableCoinDesk = await ethers.getContractFactory("StableCoinDesk")
    hardhatStableCoinDesk = await upgrades.deployProxy(stableCoinDesk, [
      hardhatAlloyxConfig.address,
    ])
    await hardhatStableCoinDesk.deployed()
    stakeDesk = await ethers.getContractFactory("StakeDesk")
    hardhatStakeDesk = await upgrades.deployProxy(stakeDesk, [hardhatAlloyxConfig.address])
    await hardhatStableCoinDesk.deployed()
    treasury = await ethers.getContractFactory("AlloyxTreasury")
    hardhatAlloyxTreasury = await upgrades.deployProxy(treasury, [hardhatAlloyxConfig.address])
    await hardhatAlloyxTreasury.deployed()
    exchange = await ethers.getContractFactory("AlloyxExchange")
    hardhatAlloyxExchange = await upgrades.deployProxy(exchange, [hardhatAlloyxConfig.address])
    await hardhatAlloyxExchange.deployed()
    seniorPool = await ethers.getContractFactory("SeniorPool")
    hardhatSeniorPool = await seniorPool.deploy(3, hardhatFiduCoin.address, hardhatUsdcCoin.address)
    goldFinchPoolToken = await ethers.getContractFactory("PoolTokens")
    hardhatPoolTokens = await goldFinchPoolToken.deploy(hardhatSeniorPool.address)
    tranchedPool = await ethers.getContractFactory("TranchedPool")
    hardhatTranchedPool = await tranchedPool.deploy(
      hardhatPoolTokens.address,
      hardhatUsdcCoin.address
    )
    sortedGoldfinchTranches = await ethers.getContractFactory("SortedGoldfinchTranches")
    hardhatSortedGoldfinchTranches = await sortedGoldfinchTranches.deploy()
    uidERC1155 = await ethers.getContractFactory("UniqueIdentity")
    hardhatUidErc1155 = await uidERC1155.deploy()
    alloyxWhitelist = await ethers.getContractFactory("AlloyxWhitelist")
    hardhatAlloyxWhitelist = await alloyxWhitelist.deploy(hardhatUidErc1155.address)

    await hardhatPoolTokens.setPoolAddress(hardhatTranchedPool.address)
    await hardhatFiduCoin.transferOwnership(hardhatSeniorPool.address)
    // await hardhatUsdcCoin.mint(hardhatVault.address, INITIAL_USDC_BALANCE)
    await hardhatGfiCoin.mint(hardhatAlloyxTreasury.address, INITIAL_GFI_BALANCE)
    await hardhatUsdcCoin.mint(hardhatAlloyxTreasury.address, INITIAL_USDC_BALANCE)
    await hardhatAlloyxTokenDURA.mint(
      hardhatAlloyxTreasury.address,
      INITIAL_USDC_BALANCE.div(USDC_MANTISSA).mul(ALLOY_MANTISSA)
    )
    await hardhatAlloyxConfig.setAddress(0, hardhatAlloyxTreasury.address)
    await hardhatAlloyxConfig.setAddress(1, hardhatAlloyxExchange.address)
    await hardhatAlloyxConfig.setAddress(2, hardhatAlloyxConfig.address)
    await hardhatAlloyxConfig.setAddress(3, hardhatGoldfinchDesk.address)
    await hardhatAlloyxConfig.setAddress(4, hardhatStableCoinDesk.address)
    await hardhatAlloyxConfig.setAddress(5, hardhatStakeDesk.address)
    await hardhatAlloyxConfig.setAddress(6, hardhatAlloyxWhitelist.address)
    await hardhatAlloyxConfig.setAddress(7, hardhatAlloyxStakeInfo.address)
    await hardhatAlloyxConfig.setAddress(8, hardhatPoolTokens.address)
    await hardhatAlloyxConfig.setAddress(9, hardhatSeniorPool.address)
    await hardhatAlloyxConfig.setAddress(10, hardhatSortedGoldfinchTranches.address)
    await hardhatAlloyxConfig.setAddress(11, hardhatFiduCoin.address)
    await hardhatAlloyxConfig.setAddress(12, hardhatGfiCoin.address)
    await hardhatAlloyxConfig.setAddress(13, hardhatUsdcCoin.address)
    await hardhatAlloyxConfig.setAddress(14, hardhatAlloyxTokenDURA.address)
    await hardhatAlloyxConfig.setAddress(15, hardhatAlloyxTokenCRWN.address)

    await hardhatAlloyxConfig.setNumber(0, 1)
    await hardhatAlloyxConfig.setNumber(1, 1)
    await hardhatAlloyxConfig.setNumber(2, 2)
    await hardhatAlloyxConfig.setNumber(3, 10)
    await hardhatAlloyxConfig.setNumber(4, 1)
    await hardhatAlloyxConfig.setNumber(6, 2)

    await hardhatAlloyxTokenCRWN.addAdmin(hardhatGoldfinchDesk.address)
    await hardhatAlloyxTokenCRWN.addAdmin(hardhatStableCoinDesk.address)
    await hardhatAlloyxTokenCRWN.addAdmin(hardhatStakeDesk.address)
    await hardhatAlloyxTokenDURA.addAdmin(hardhatGoldfinchDesk.address)
    await hardhatAlloyxTokenDURA.addAdmin(hardhatStableCoinDesk.address)
    await hardhatAlloyxTokenDURA.addAdmin(hardhatStakeDesk.address)
    await hardhatAlloyxTreasury.addAdmin(hardhatGoldfinchDesk.address)
    await hardhatAlloyxTreasury.addAdmin(hardhatStableCoinDesk.address)
    await hardhatAlloyxTreasury.addAdmin(hardhatStakeDesk.address)
    await hardhatAlloyxStakeInfo.addAdmin(hardhatGoldfinchDesk.address)
    await hardhatAlloyxStakeInfo.addAdmin(hardhatStableCoinDesk.address)
    await hardhatAlloyxStakeInfo.addAdmin(hardhatStakeDesk.address)
  })

  describe("Basic Usecases", function () {
    it("Get DURA Balance of Vault Upon start", async function () {
      const balance = await hardhatAlloyxTokenDURA.balanceOf(hardhatAlloyxTreasury.address)
      expect(balance).to.equal(INITIAL_USDC_BALANCE.div(USDC_MANTISSA).mul(ALLOY_MANTISSA))
    })

    it("Mint pool tokens for vault", async function () {
      await hardhatPoolTokens.mint([100000, 999], hardhatAlloyxTreasury.address)
      await hardhatPoolTokens.mint([200000, 999], hardhatAlloyxTreasury.address)
      await hardhatPoolTokens.mint([300000, 999], hardhatAlloyxTreasury.address)
      await hardhatPoolTokens.mint([400000, 999], hardhatAlloyxTreasury.address)
      const balance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      expect(balance).to.equal(4)
    })

    it("Get token value:getGoldfinchDelegacyBalanceInUSDC", async function () {
      const token1Value = await hardhatGoldfinchDesk.getJuniorTokenValue(1)
      const token2Value = await hardhatGoldfinchDesk.getJuniorTokenValue(2)
      const token3Value = await hardhatGoldfinchDesk.getJuniorTokenValue(3)
      const token4Value = await hardhatGoldfinchDesk.getJuniorTokenValue(4)
      const totalValue = await hardhatGoldfinchDesk.getGoldFinchPoolTokenBalanceInUsdc()
      expect(totalValue).to.equal(token1Value.add(token2Value).add(token3Value).add(token4Value))
    })

    it("Get total USDC value of vault:getAlloyxDURATokenBalanceInUSDC", async function () {
      const totalVaultValue = await hardhatAlloyxExchange.getTreasuryTotalBalanceInUsdc()
      const pooltokenValue = await hardhatGoldfinchDesk.getGoldFinchPoolTokenBalanceInUsdc()
      expect(totalVaultValue).to.equal(pooltokenValue.add(INITIAL_USDC_BALANCE))
    })

    it("Check the alloy token supply:alloyxDuraToUsdc", async function () {
      const totalVaultValue = await hardhatAlloyxExchange.getTreasuryTotalBalanceInUsdc()
      const totalSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const expectedTotalVaultValue = await hardhatAlloyxExchange.alloyxDuraToUsdc(
        totalSupplyOfDURAToken
      )
      expect(expectedTotalVaultValue).to.equal(totalVaultValue)
    })

    it("Check the alloy token supply: usdcToAlloyxDura", async function () {
      const totalVaultValue = await hardhatAlloyxExchange.getTreasuryTotalBalanceInUsdc()
      const totalSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const expectedTotalSupplyOfDURAToken = await hardhatAlloyxExchange.usdcToAlloyxDura(
        totalVaultValue
      )
      expect(totalSupplyOfDURAToken).to.equal(expectedTotalSupplyOfDURAToken)
    })

    it("Deposit USDC tokens:depositUSDCCoin", async function () {
      await hardhatAlloyxWhitelist.addWhitelistedUser(addr1.address)
      await hardhatUsdcCoin.mint(addr1.address, ethers.BigNumber.from(10).pow(6).mul(5))
      const prevSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const usdcToDeposit = 5000000
      await hardhatUsdcCoin.connect(addr1).approve(hardhatStableCoinDesk.address, usdcToDeposit)
      await hardhatStableCoinDesk.connect(addr1).depositUSDCCoin(usdcToDeposit, false)
      const additionalDURAMinted = await hardhatAlloyxExchange.usdcToAlloyxDura(usdcToDeposit)
      const postSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      expect(postSupplyOfDURAToken).to.equal(additionalDURAMinted.add(prevSupplyOfDURAToken))
    })

    it("Deposit Alloy DURA tokens For Fidu:depositAlloyxDURATokensForFIDU", async function () {
      const prevSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const preFidu = await hardhatFiduCoin.balanceOf(addr1.address)
      const alloyxDURAToDeposit = ethers.BigNumber.from(10).pow(17)
      const percentageDuraToFidu = 1
      const expectedUSDC = await hardhatAlloyxExchange.alloyxDuraToUsdc(alloyxDURAToDeposit)
      const fee = expectedUSDC.mul(percentageDuraToFidu).div(100)
      const usdcTransfered = expectedUSDC.sub(fee)
      const prevUSDC = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      await hardhatGoldfinchDesk.connect(addr1).depositDuraForFidu(alloyxDURAToDeposit)
      const postFidu = await hardhatFiduCoin.balanceOf(addr1.address)
      const postUSDC = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      expect(prevUSDC.sub(postUSDC)).to.equal(usdcTransfered)
      expect(postFidu.sub(preFidu)).to.gt(0)
      const postSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      expect(postSupplyOfDURAToken).to.equal(prevSupplyOfDURAToken.sub(alloyxDURAToDeposit))
    })

    it("Deposit Alloy DURA tokens:depositAlloyxDURATokens", async function () {
      const prevSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const alloyxDURAToDeposit = ethers.BigNumber.from(10).pow(17)
      await hardhatStableCoinDesk.connect(addr1).depositAlloyxDURATokens(alloyxDURAToDeposit)
      const postSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      expect(postSupplyOfDURAToken).to.equal(prevSupplyOfDURAToken.sub(alloyxDURAToDeposit))
    })

    it("Deposit NFT tokens:depositNFTTokenForUsdc", async function () {
      const prevPoolTokenValue = await hardhatAlloyxExchange.getTreasuryTotalBalanceInUsdc()
      const prevPoolTokenBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      await hardhatPoolTokens.mint([400, 999], addr1.address)
      await hardhatUsdcCoin.mint(
        hardhatAlloyxTreasury.address,
        ethers.BigNumber.from(10).pow(6).mul(5)
      )
      const prevUSDC = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const token5Value = await hardhatGoldfinchDesk.getJuniorTokenValue(5)
      await hardhatPoolTokens.connect(addr1).approve(hardhatGoldfinchDesk.address, 5)
      await hardhatGoldfinchDesk.connect(addr1).depositPoolTokensForUsdc(5)
      const postUSDC = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const postPoolTokenValue = await hardhatAlloyxExchange.getTreasuryTotalBalanceInUsdc()
      const postPoolTokenBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      expect(prevUSDC.sub(postUSDC)).to.equal(token5Value)
      expect(postPoolTokenValue).to.equal(
        ethers.BigNumber.from(10).pow(6).mul(5).add(prevPoolTokenValue)
      )
      expect(postPoolTokenBalance).to.equal(prevPoolTokenBalance.add(1))
    })

    it("Deposit NFT tokens:depositNFTTokenForDura", async function () {
      const prevPoolTokenBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      await hardhatPoolTokens.mint([600, 999], addr1.address)
      const prevDura = await hardhatAlloyxTokenDURA.balanceOf(addr1.address)
      const token6Value = await hardhatGoldfinchDesk.getJuniorTokenValue(6)
      const additionalDURAMinted = await hardhatAlloyxExchange.usdcToAlloyxDura(token6Value)
      await hardhatPoolTokens.connect(addr1).approve(hardhatGoldfinchDesk.address, 6)
      await hardhatGoldfinchDesk.connect(addr1).depositPoolTokenForDura(6, false)
      const postDura = await hardhatAlloyxTokenDURA.balanceOf(addr1.address)
      const postPoolTokenBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      expect(postDura.sub(prevDura)).to.equal(additionalDURAMinted)
      expect(postPoolTokenBalance).to.equal(prevPoolTokenBalance.add(1))
    })

    it("Deposit NFT tokens:depositNFTTokenForDuraWithStake", async function () {
      const prevPoolTokenBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      await hardhatPoolTokens.mint([600, 999], addr1.address)
      const prevDura = await hardhatAlloyxTokenDURA.balanceOf(hardhatAlloyxTreasury.address)
      const preStake = (await hardhatAlloyxStakeInfo.stakeOf(addr1.address))[0]
      const token7Value = await hardhatGoldfinchDesk.getJuniorTokenValue(7)
      const additionalDURAMinted = await hardhatAlloyxExchange.usdcToAlloyxDura(token7Value)
      await hardhatPoolTokens.connect(addr1).approve(hardhatGoldfinchDesk.address, 7)
      await hardhatGoldfinchDesk.connect(addr1).depositPoolTokenForDura(7, true)
      const postDura = await hardhatAlloyxTokenDURA.balanceOf(hardhatAlloyxTreasury.address)
      const postPoolTokenBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      const postStake = (await hardhatAlloyxStakeInfo.stakeOf(addr1.address))[0]
      expect(postStake.sub(preStake)).eq(additionalDURAMinted)
      expect(postDura.sub(prevDura)).to.equal(additionalDURAMinted)
      expect(postPoolTokenBalance).to.equal(prevPoolTokenBalance.add(1))
    })

    it("Deposit Dura for NFT: depositAlloyxDURATokensForNft", async function () {
      const tokenIdsForAddr1 = await hardhatGoldfinchDesk.getTokensAvailableForWithdrawal(
        addr1.address
      )
      expect(tokenIdsForAddr1[0]).to.equal(5)
      expect(tokenIdsForAddr1[1]).to.equal(6)
      expect(tokenIdsForAddr1[2]).to.equal(7)
      const prevDura = await hardhatAlloyxTokenDURA.balanceOf(addr1.address)
      const prevPoolTokenBalance = await hardhatPoolTokens.balanceOf(addr1.address)
      const purchasePrice = await hardhatGoldfinchDesk.getJuniorTokenValue(7)
      const percentageJuniorRedemption = 1
      const withdrawalFee = purchasePrice.mul(percentageJuniorRedemption).div(100)
      const duraCosted = await hardhatAlloyxExchange.usdcToAlloyxDura(
        purchasePrice.add(withdrawalFee)
      )
      await hardhatGoldfinchDesk.connect(addr1).depositDuraForPoolToken(7)
      const tokenIdsForAddr1Post = await hardhatGoldfinchDesk.getTokensAvailableForWithdrawal(
        addr1.address
      )
      const postPoolTokenBalance = await hardhatPoolTokens.balanceOf(addr1.address)
      const postDura = await hardhatAlloyxTokenDURA.balanceOf(addr1.address)
      expect(tokenIdsForAddr1Post[0]).to.equal(5)
      expect(tokenIdsForAddr1Post[1]).to.equal(6)
      expect(tokenIdsForAddr1Post.length).to.equal(2)
      expect(postPoolTokenBalance.sub(prevPoolTokenBalance)).to.equal(1)
      expect(prevDura.sub(postDura)).to.equal(duraCosted)
    })

    it("Purchase junior token:purchaseJuniorToken", async function () {
      const preBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      const purchaseFee = 60000
      await hardhatGoldfinchDesk.purchasePoolToken(
        purchaseFee,
        hardhatTranchedPool.address,
        purchaseFee
      )
      const postBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      expect(postBalance).to.equal(preBalance.add(1))
    })

    it("Purchase senior token:purchaseSeniorTokens", async function () {
      const preBalance = await hardhatFiduCoin.balanceOf(hardhatAlloyxTreasury.address)
      const purchaseFee = 6000
      const shares = await hardhatSeniorPool.getNumShares(purchaseFee)
      await hardhatGoldfinchDesk.purchaseFIDU(purchaseFee)
      const postBalance = await hardhatFiduCoin.balanceOf(hardhatAlloyxTreasury.address)
      expect(postBalance).to.equal(preBalance.add(shares))
    })

    it("Sell senior token:sellSeniorTokens", async function () {
      const preBalance = await hardhatFiduCoin.balanceOf(hardhatAlloyxTreasury.address)
      const preRepaymentFee = await hardhatAlloyxTreasury.getRepaymentFee()
      const preUsdcBalance = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const sellUsdc = ethers.BigNumber.from(3000)
      const percentageDURARepayment = 2
      const shares = await hardhatSeniorPool.getNumShares(sellUsdc)
      await hardhatGoldfinchDesk.sellFIDU(shares)
      const postBalance = await hardhatFiduCoin.balanceOf(hardhatAlloyxTreasury.address)
      const postUsdcBalance = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const postRepaymentFee = await hardhatAlloyxTreasury.getRepaymentFee()
      expect(preBalance.sub(postBalance)).to.equal(shares)
      expect(postUsdcBalance.sub(preUsdcBalance)).to.equal(sellUsdc)
      expect(postRepaymentFee.sub(preRepaymentFee)).to.equal(
        sellUsdc.mul(percentageDURARepayment).div(100)
      )
    })

    it("Withdraw from junior token:withdrawFromJuniorTokens", async function () {
      const preRepaymentFee = await hardhatAlloyxTreasury.getRepaymentFee()
      const preUsdcBalance = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const withdrawalAmount = ethers.BigNumber.from(500)
      const percentageDURARepayment = 2
      await hardhatGoldfinchDesk.withdrawFromJuniorToken(
        1,
        withdrawalAmount,
        hardhatTranchedPool.address
      )
      const postUsdcBalance = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const postRepaymentFee = await hardhatAlloyxTreasury.getRepaymentFee()
      expect(postUsdcBalance.sub(preUsdcBalance)).to.equal(withdrawalAmount)
      expect(postRepaymentFee.sub(preRepaymentFee)).to.equal(
        withdrawalAmount.mul(percentageDURARepayment).div(100)
      )
    })

    it("Migrate all PoolTokens:migrateAllERC721Enumerable", async function () {
      const preVaultBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      const preOwnerBalance = await hardhatPoolTokens.balanceOf(owner.address)
      await hardhatAlloyxTreasury.migrateAllERC721Enumerable(
        hardhatPoolTokens.address,
        owner.address
      )
      const postVaultBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      const postOwnerBalance = await hardhatPoolTokens.balanceOf(owner.address)
      expect(postOwnerBalance.sub(preOwnerBalance)).to.equal(preVaultBalance.sub(postVaultBalance))
      expect(postVaultBalance).to.equal(0)
    })

    it("Migrate all USDC:migrateERC20", async function () {
      const preVaultBalance = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const preOwnerBalance = await hardhatUsdcCoin.balanceOf(owner.address)
      await hardhatAlloyxTreasury.migrateERC20(hardhatUsdcCoin.address, owner.address)
      const postVaultBalance = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const postOwnerBalance = await hardhatUsdcCoin.balanceOf(owner.address)
      expect(postOwnerBalance.sub(preOwnerBalance)).to.equal(preVaultBalance.sub(postVaultBalance))
      expect(postVaultBalance).to.equal(0)
    })

    it("stake and unstake", async function () {
      await hardhatAlloyxWhitelist.addWhitelistedUser(addr3.address)
      await hardhatUsdcCoin.mint(addr3.address, ethers.BigNumber.from(10).pow(6).mul(5))
      const usdcToDeposit = 5000000
      const additionalDURAMinted = await hardhatAlloyxExchange.usdcToAlloyxDura(usdcToDeposit)
      await hardhatUsdcCoin.connect(addr3).approve(hardhatStableCoinDesk.address, usdcToDeposit)
      await hardhatStableCoinDesk.connect(addr3).depositUSDCCoin(usdcToDeposit, false)
      expect(await hardhatAlloyxTokenDURA.balanceOf(addr3.address)).to.equal(additionalDURAMinted)
      await hardhatAlloyxTokenDURA
        .connect(addr3)
        .approve(hardhatStakeDesk.address, additionalDURAMinted)
      const preVaultDURA = await hardhatAlloyxTokenDURA.balanceOf(hardhatAlloyxTreasury.address)
      await hardhatStakeDesk.connect(addr3).stake(additionalDURAMinted)
      const halfAYear = (365 * 24 * 60 * 60) / 2
      await ethers.provider.send("evm_increaseTime", [halfAYear])
      await ethers.provider.send("evm_mine")
      const percentageRewardPerYear = 2
      const redeemable = await hardhatAlloyxStakeInfo
        .connect(addr3)
        .claimableCRWNToken(addr3.address)
      const postVaultDURA = await hardhatAlloyxTokenDURA.balanceOf(hardhatAlloyxTreasury.address)
      expect(await hardhatAlloyxTokenDURA.balanceOf(addr3.address)).to.equal(0)
      expect((await hardhatAlloyxStakeInfo.stakeOf(addr3.address))[0]).to.equal(
        additionalDURAMinted
      )
      expect(postVaultDURA.sub(preVaultDURA)).to.equal(additionalDURAMinted)
      expect(redeemable).to.equal(additionalDURAMinted.mul(percentageRewardPerYear).div(100).div(2))
      await hardhatStakeDesk.connect(addr3).unstake(additionalDURAMinted.div(5))
      const postVaultDURA1 = await hardhatAlloyxTokenDURA.balanceOf(hardhatAlloyxTreasury.address)
      expect(postVaultDURA.sub(postVaultDURA1)).to.equal(additionalDURAMinted.div(5))
      expect(await hardhatAlloyxTokenDURA.balanceOf(addr3.address)).to.equal(
        additionalDURAMinted.div(5)
      )
      const duraStakedPre = await hardhatAlloyxStakeInfo.stakeOf(addr3.address)
      await hardhatStakeDesk.connect(addr3).claimAlloyxCRWN(redeemable.div(2))
      const duraStakedPost = await hardhatAlloyxStakeInfo.stakeOf(addr3.address)
      expect(duraStakedPre.amount).to.equal(duraStakedPost.amount)
      expect(await hardhatAlloyxTokenCRWN.balanceOf(addr3.address)).to.equal(redeemable.div(2))
      const redeemable2 = await hardhatAlloyxStakeInfo
        .connect(addr3)
        .claimableCRWNToken(addr3.address)
      expect(redeemable2.sub(redeemable.div(2)).div(redeemable2).mul(1000)).to.lt(1)
      const duraStakedPre1 = await hardhatAlloyxStakeInfo.stakeOf(addr3.address)
      const preCrown = await await hardhatAlloyxTokenCRWN.balanceOf(addr3.address)
      const redeemable3 = await hardhatAlloyxStakeInfo
        .connect(addr3)
        .claimableCRWNToken(addr3.address)
      await hardhatStakeDesk.connect(addr3).claimAllAlloyxCRWN()
      const redeemable4 = await hardhatAlloyxStakeInfo
        .connect(addr3)
        .claimableCRWNToken(addr3.address)
      const duraStakedPost1 = await hardhatAlloyxStakeInfo.stakeOf(addr3.address)
      expect(duraStakedPre1.amount).to.equal(duraStakedPost1.amount)
      expect(redeemable4).to.equal(0)
      const postCrown = await hardhatAlloyxTokenCRWN.balanceOf(addr3.address)
      expect(postCrown.sub(preCrown).sub(redeemable3).div(redeemable3).mul(100000)).to.lt(1)
    })

    it("Transaction fee of percentageDURARedemption:depositAlloyxDURATokens", async function () {
      const prevSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      const alloyxDURAToDeposit = ethers.BigNumber.from(10).pow(17)
      const percentageDURARedemption = 1
      const expectedUSDC = await hardhatAlloyxExchange.alloyxDuraToUsdc(alloyxDURAToDeposit)
      const fee = expectedUSDC.mul(percentageDURARedemption).div(100)
      const preUsdcBalanceAddr1 = await hardhatUsdcCoin.balanceOf(addr1.address)
      const preUsdcBalanceVault = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const preVaultFee = await hardhatAlloyxTreasury.getRedemptionFee()
      await hardhatAlloyxTokenDURA
        .connect(addr1)
        .approve(hardhatAlloyxTreasury.address, alloyxDURAToDeposit)
      const preUsdcBalanceOfDelegacy = await hardhatUsdcCoin.balanceOf(
        hardhatAlloyxTreasury.address
      )
      await hardhatStableCoinDesk.connect(addr1).depositAlloyxDURATokens(alloyxDURAToDeposit)
      const postUsdcBalanceAddr1 = await hardhatUsdcCoin.balanceOf(addr1.address)
      const postUsdcBalanceVault = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const postUsdcBalanceOfDelegacy = await hardhatUsdcCoin.balanceOf(
        hardhatAlloyxTreasury.address
      )
      const postVaultFee = await hardhatAlloyxTreasury.getRedemptionFee()
      const postSupplyOfDURAToken = await hardhatAlloyxTokenDURA.totalSupply()
      expect(postSupplyOfDURAToken).to.equal(prevSupplyOfDURAToken.sub(alloyxDURAToDeposit))
      expect(postUsdcBalanceAddr1.sub(preUsdcBalanceAddr1)).to.equal(expectedUSDC.sub(fee))
      expect(preUsdcBalanceOfDelegacy.sub(postUsdcBalanceOfDelegacy)).to.equal(
        expectedUSDC.sub(fee)
      )
      expect(postVaultFee.sub(preVaultFee)).to.equal(fee)
    })

    it("totalClaimableAndClaimedCRWNToken", async function () {
      const claimable1 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr1.address)
      const claimable2 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr2.address)
      const claimable3 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr3.address)
      const claimableOwner = await hardhatAlloyxStakeInfo.claimableCRWNToken(owner.address)
      const totalClaimed = await hardhatAlloyxTokenCRWN.totalSupply()
      const expectedTotal = await hardhatStakeDesk.totalClaimableAndClaimedCRWNToken()
      expect(
        expectedTotal
          .sub(totalClaimed.add(claimableOwner).add(claimable1).add(claimable2).add(claimable3))
          .mul(1000000000)
          .div(expectedTotal)
      ).to.lt(1)
    })

    it("Transaction fee of percentageCRWNEarning:claimReward", async function () {
      const totalClaimedAndClaimable = await hardhatStakeDesk.totalClaimableAndClaimedCRWNToken()
      const preEarningFee = await hardhatAlloyxTreasury.getEarningGfiFee()
      const preCRWNBalance = await hardhatAlloyxTokenCRWN.balanceOf(addr3.address)
      const preGfiBalance = await hardhatGfiCoin.balanceOf(addr3.address)
      const amountToRewardToClaim = preCRWNBalance.div(3)
      const gfiBalance = await hardhatGfiCoin.balanceOf(hardhatAlloyxTreasury.address)
      const percentageEarningFee = 10
      const totalRewardToProcess = amountToRewardToClaim
        .mul(gfiBalance.sub(preEarningFee))
        .div(totalClaimedAndClaimable)
      const earningFee = totalRewardToProcess.mul(percentageEarningFee).div(100)
      const [rewardAmount, fee] = await hardhatStakeDesk
        .connect(addr3)
        .getRewardTokenCount(amountToRewardToClaim)
      await hardhatStakeDesk.connect(addr3).claimReward(amountToRewardToClaim)
      const postEarningFee = await hardhatAlloyxTreasury.getEarningGfiFee()
      expect(postEarningFee.sub(preEarningFee).sub(earningFee).div(earningFee).mul(100000)).to.lt(1)
      const postCRWNBalance = await hardhatAlloyxTokenCRWN.balanceOf(addr3.address)
      const postGfiBalance = await hardhatGfiCoin.balanceOf(addr3.address)
      const postGfiBalanceOfDelegacy = await hardhatGfiCoin.balanceOf(hardhatAlloyxTreasury.address)
      expect(
        postGfiBalance
          .sub(preGfiBalance)
          .sub(rewardAmount.sub(fee))
          .div(rewardAmount.sub(fee))
          .mul(100000)
      ).to.lt(1)
      expect(preCRWNBalance.sub(postCRWNBalance)).to.equal(amountToRewardToClaim)
      expect(
        postGfiBalance
          .sub(preGfiBalance)
          .sub(totalRewardToProcess.sub(earningFee))
          .div(totalRewardToProcess.sub(earningFee))
          .mul(100000)
      ).to.lt(1)
    })

    it("stake and unstake many times", async function () {
      await hardhatAlloyxWhitelist.addWhitelistedUser(addr9.address)
      await hardhatUsdcCoin.mint(addr9.address, ethers.BigNumber.from(10).pow(10).mul(5))
      const preUsdcBalanceAddr9 = await hardhatUsdcCoin.balanceOf(addr9.address)
      const usdcToDeposit = 1000000000
      const additionalDURAMinted = await hardhatAlloyxExchange.usdcToAlloyxDura(usdcToDeposit)
      await hardhatUsdcCoin.connect(addr9).approve(hardhatStableCoinDesk.address, usdcToDeposit)
      const preAlloyDURABalanceVault = await hardhatAlloyxTokenDURA.balanceOf(
        hardhatAlloyxTreasury.address
      )
      await hardhatStableCoinDesk.connect(addr9).depositUSDCCoin(usdcToDeposit, true)
      const fiftyYears = 365 * 24 * 60 * 60 * 50
      await ethers.provider.send("evm_increaseTime", [fiftyYears])
      await ethers.provider.send("evm_mine")
      const percentageRewardPerYear = 2
      const redeemable = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr9.address)
      expect(redeemable).to.equal(
        additionalDURAMinted.mul(percentageRewardPerYear).mul(50).div(100)
      )
      const postUsdcBalanceAddr9 = await hardhatUsdcCoin.balanceOf(addr9.address)
      const postAlloyDURABalanceVault = await hardhatAlloyxTokenDURA.balanceOf(
        hardhatAlloyxTreasury.address
      )
      expect(postAlloyDURABalanceVault.sub(preAlloyDURABalanceVault)).to.equal(additionalDURAMinted)
      expect(preUsdcBalanceAddr9.sub(postUsdcBalanceAddr9)).to.equal(usdcToDeposit)
      await hardhatStakeDesk.connect(addr9).unstake(additionalDURAMinted.div(8))
      const postDURABalanceAddr9 = await hardhatAlloyxTokenDURA.balanceOf(addr9.address)
      expect(postDURABalanceAddr9).to.equal(additionalDURAMinted.div(8))
      await hardhatStakeDesk.connect(addr9).unstake(additionalDURAMinted.div(4))
      const postDURABalanceAddr9_2 = await hardhatAlloyxTokenDURA.balanceOf(addr9.address)
      expect(postDURABalanceAddr9_2).to.equal(
        additionalDURAMinted.div(4).add(additionalDURAMinted.div(8))
      )
      const redeemable2 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr9.address)
      const twentyYears = 365 * 24 * 60 * 60 * 20
      await ethers.provider.send("evm_increaseTime", [twentyYears])
      await ethers.provider.send("evm_mine")
      const redeemable3 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr9.address)
      const stakedAmount = additionalDURAMinted.sub(
        additionalDURAMinted.div(4).add(additionalDURAMinted.div(8))
      )
      expect(redeemable3.sub(redeemable2)).to.equal(
        stakedAmount.mul(percentageRewardPerYear).mul(20).div(100)
      )
      await hardhatAlloyxTokenDURA
        .connect(addr9)
        .approve(hardhatStakeDesk.address, additionalDURAMinted.div(10))
      await hardhatStakeDesk.connect(addr9).stake(additionalDURAMinted.div(10))
      const redeemable4 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr9.address)
      const tenYears = 365 * 24 * 60 * 60 * 10
      await ethers.provider.send("evm_increaseTime", [tenYears])
      await ethers.provider.send("evm_mine")
      const redeemable5 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr9.address)
      expect(redeemable5.sub(redeemable4)).to.equal(
        stakedAmount.add(additionalDURAMinted.div(10)).mul(percentageRewardPerYear).mul(10).div(100)
      )
      await hardhatAlloyxTokenDURA
        .connect(addr9)
        .approve(hardhatStakeDesk.address, additionalDURAMinted.div(20))
      await hardhatStakeDesk.connect(addr9).stake(additionalDURAMinted.div(20))
      const fiveYears = 365 * 24 * 60 * 60 * 5
      const redeemable6 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr9.address)
      await ethers.provider.send("evm_increaseTime", [fiveYears])
      await ethers.provider.send("evm_mine")
      const redeemable7 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr9.address)
      expect(redeemable7.sub(redeemable6)).to.equal(
        stakedAmount
          .add(additionalDURAMinted.div(10))
          .add(additionalDURAMinted.div(20))
          .mul(percentageRewardPerYear)
          .mul(5)
          .div(100)
      )
    })

    it("totalClaimableAndClaimedCRWNToken for more accounts", async function () {
      const claimable1 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr1.address)
      const claimable2 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr2.address)
      const claimable3 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr3.address)
      const claimable4 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr4.address)
      const claimable5 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr5.address)
      const claimable6 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr6.address)
      const claimable7 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr7.address)
      const claimable8 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr8.address)
      const claimable9 = await hardhatAlloyxStakeInfo.claimableCRWNToken(addr9.address)
      const claimableOwner = await hardhatAlloyxStakeInfo.claimableCRWNToken(owner.address)
      const totalClaimed = await hardhatAlloyxTokenCRWN.totalSupply()
      const expectedTotal = await hardhatStakeDesk.totalClaimableAndClaimedCRWNToken()
      expect(
        expectedTotal
          .sub(
            totalClaimed
              .add(claimableOwner)
              .add(claimable1)
              .add(claimable2)
              .add(claimable3)
              .add(claimable4)
              .add(claimable5)
              .add(claimable6)
              .add(claimable7)
              .add(claimable8)
              .add(claimable9)
          )
          .sub(expectedTotal)
          .div(expectedTotal)
          .mul(1000000000)
      ).lt(1)
    })

    it("whitelist functions", async function () {
      await hardhatAlloyxWhitelist.addWhitelistedUser(addr2.address)
      const whitelisted = await hardhatAlloyxWhitelist.isUserWhitelisted(addr2.address)
      expect(whitelisted).to.equal(true)
      await hardhatAlloyxWhitelist.removeWhitelistedUser(addr2.address)
      const whitelisted1 = await hardhatAlloyxWhitelist.isUserWhitelisted(addr2.address)
      expect(whitelisted1).to.equal(false)
    })

    it("goldfinch whitelist functions", async function () {
      const whitelisted1 = await hardhatAlloyxWhitelist.isUserWhitelisted(addr2.address)
      expect(whitelisted1).to.equal(false)
      await hardhatUidErc1155.connect(addr2).mint(0)
      const whitelisted = await hardhatAlloyxWhitelist.isUserWhitelisted(addr2.address)
      expect(whitelisted).to.equal(true)
    })

    it("migrateERC20 in vault functions", async function () {
      const preVaultBalance = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const preOwnerBalance = await hardhatUsdcCoin.balanceOf(owner.address)
      await hardhatAlloyxTreasury.migrateERC20(hardhatUsdcCoin.address, owner.address)
      const postVaultBalance = await hardhatUsdcCoin.balanceOf(hardhatAlloyxTreasury.address)
      const postOwnerBalance = await hardhatUsdcCoin.balanceOf(owner.address)
      expect(postOwnerBalance.sub(preOwnerBalance)).to.equal(preVaultBalance.sub(postVaultBalance))
      expect(postVaultBalance).to.equal(0)
    })

    it("migrateERC721 in vault functions", async function () {
      await hardhatPoolTokens.mint([600, 999], hardhatAlloyxTreasury.address)
      const preVaultBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      const preOwnerBalance = await hardhatPoolTokens.balanceOf(owner.address)
      await hardhatAlloyxTreasury.transferERC721(hardhatPoolTokens.address, owner.address, 9)
      const postVaultBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      const postOwnerBalance = await hardhatPoolTokens.balanceOf(owner.address)
      expect(postOwnerBalance.sub(preOwnerBalance)).to.equal(preVaultBalance.sub(postVaultBalance))
      expect(postVaultBalance).to.equal(0)
    })

    it("Purchase junior token beyond usdc threshold:purchaseJuniorTokenBeyondUsdcThreshold", async function () {
      const preBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      await hardhatSortedGoldfinchTranches.addTranch(hardhatTranchedPool.address, 1)
      await hardhatUsdcCoin.mint(
        hardhatAlloyxTreasury.address,
        ethers.BigNumber.from(10).pow(30).mul(5)
      )
      await hardhatGoldfinchDesk.purchaseJuniorTokenBeyondUsdcThreshold()
      const postBalance = await hardhatPoolTokens.balanceOf(hardhatAlloyxTreasury.address)
      expect(postBalance).to.equal(preBalance.add(1))
    })
  })
})
