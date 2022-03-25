const { expect } = require("chai");

describe("AlloyVault V2 contract", function () {
  let alloyxTokenBronze;
  let vault;
  let usdcCoin;
  let gfiCoin;
  let fiduCoin;
  let goldFinchPoolToken;
  let seniorPool;
  let tranchedPool;
  let owner;
  let addr1;
  let addr2;
  let addrs;
  const INITIAL_USDC_BALANCE=ethers.BigNumber.from(10).pow(6).mul(5)
  const USDC_MANTISSA=ethers.BigNumber.from(10).pow(6)
  const ALLOY_MANTISSA=ethers.BigNumber.from(10).pow(18)


  before(async function () {

    fiduCoin = await ethers.getContractFactory("FIDU");
    hardhatFiduCoin = await fiduCoin.deploy();
    gfiCoin = await ethers.getContractFactory("GFI");
    hardhatGfiCoin = await gfiCoin.deploy();
    usdcCoin = await ethers.getContractFactory("USDC");
    hardhatUsdcCoin = await usdcCoin.deploy();
    alloyxTokenBronze = await ethers.getContractFactory("AlloyxTokenBronze");
    hardhatAlloyxTokenBronze = await alloyxTokenBronze.deploy();
    seniorPool = await ethers.getContractFactory("SeniorPool");
    hardhatSeniorPool = await seniorPool.deploy(3,hardhatFiduCoin.address,hardhatUsdcCoin.address);
    goldFinchPoolToken = await ethers.getContractFactory("PoolTokens");
    hardhatPoolTokens = await goldFinchPoolToken.deploy(hardhatSeniorPool.address);
    tranchedPool = await ethers.getContractFactory("TranchedPool");
    hardhatTranchedPool = await tranchedPool.deploy(hardhatUsdcCoin.address,hardhatPoolTokens.address);
    await hardhatPoolTokens.setPoolAddress(hardhatTranchedPool.address)
    vault = await ethers.getContractFactory("AlloyVault");
    hardhatVault = await vault.deploy(hardhatAlloyxTokenBronze.address,hardhatUsdcCoin.address,hardhatFiduCoin.address,hardhatGfiCoin.address,hardhatPoolTokens.address,hardhatSeniorPool.address);
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    await hardhatUsdcCoin.mint(hardhatVault.address, INITIAL_USDC_BALANCE);
    await hardhatAlloyxTokenBronze.transferOwnership(hardhatVault.address);
    await hardhatVault.startVaultOperation();
  });


  describe("Deployment", function () {
    it("Get Bronze Balance of Vault Upon start", async function () {
      const balance = await hardhatAlloyxTokenBronze.balanceOf(hardhatVault.address)
      expect(balance).to.equal(INITIAL_USDC_BALANCE.div(USDC_MANTISSA).mul(ALLOY_MANTISSA));

    });

    it("Mint pool tokens for vault", async function () {
      await hardhatPoolTokens.mint([100000,999],hardhatVault.address)
      await hardhatPoolTokens.mint([200000,999],hardhatVault.address)
      await hardhatPoolTokens.mint([300000,999],hardhatVault.address)
      await hardhatPoolTokens.mint([400000,999],hardhatVault.address)
      const balance = await hardhatPoolTokens.balanceOf(hardhatVault.address)
      expect(balance).to.equal(4);
    });

    it("Get token value", async function () {
      const balance = await hardhatPoolTokens.balanceOf(hardhatVault.address)
      console.log(balance)
      await hardhatPoolTokens.mint([100000,999],hardhatVault.address)
      await hardhatPoolTokens.mint([200000,999],hardhatVault.address)
      await hardhatPoolTokens.mint([300000,999],hardhatVault.address)
      await hardhatPoolTokens.mint([400000,999],hardhatVault.address)
      const token1Value=await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address,1)
      const token2Value=await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address,2)
      const token3Value=await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address,3)
      const token4Value=await hardhatVault.getJuniorTokenValue(hardhatPoolTokens.address,4)
      console.log(token1Value)
      expect(balance).to.equal(4);
    });
  });

  describe("Transactions", function () {
    it("Should transfer tokens between accounts", async function () {
      await hardhatToken.mint(owner.address, 500);
      await hardhatToken.transfer(addr1.address, 50);
      const addr1Balance = await hardhatToken.balanceOf(addr1.address);
      expect(addr1Balance).to.equal(50);

      await hardhatToken.connect(addr1).transfer(addr2.address, 50);
      const addr2Balance = await hardhatToken.balanceOf(addr2.address);
      expect(addr2Balance).to.equal(50);
    });

    it("Should fail if sender doesn’t have enough tokens", async function () {
      const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);

      await expect(
        hardhatToken.connect(addr1).transfer(owner.address, 1)
      ).to.be.revertedWith("VM Exception while processing transaction: reverted with reason string 'ERC20: transfer amount exceeds balance'");

      expect(await hardhatToken.balanceOf(owner.address)).to.equal(
        initialOwnerBalance
      );
    });

    it("Should update balances after transfers", async function () {
      await hardhatToken.mint(owner.address, 500);
      const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);

      await hardhatToken.transfer(addr1.address, 100);

      await hardhatToken.transfer(addr2.address, 50);

      const finalOwnerBalance = await hardhatToken.balanceOf(owner.address);
      expect(finalOwnerBalance).to.equal(initialOwnerBalance.sub(150));

      const addr1Balance = await hardhatToken.balanceOf(addr1.address);
      expect(addr1Balance).to.equal(100);

      const addr2Balance = await hardhatToken.balanceOf(addr2.address);
      expect(addr2Balance).to.equal(50);
    });
  });
});
