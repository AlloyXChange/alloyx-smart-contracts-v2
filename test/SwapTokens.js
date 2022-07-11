const { expect } = require("chai")

describe("SwapTokens contract", function () {
  let swapTokens
  let tokenToMint
  let tokenToBurn
  let hardhatSwapTokens
  let hardhatTokenToMint
  let hardhatTokenToBurn
  let owner
  let addr1
  let addr2
  let addr3
  let addr4
  let addr5
  let addrs

  before(async function () {
    ;[owner, addr1, addr2, addr3, addr4, addr5, ...addrs] = await ethers.getSigners()
    tokenToMint = await ethers.getContractFactory("TokenToMint")
    hardhatTokenToMint = await tokenToMint.deploy()
    tokenToBurn = await ethers.getContractFactory("TokenToBurn")
    hardhatTokenToBurn = await tokenToBurn.deploy()
    swapTokens = await ethers.getContractFactory("SwapTokens")
    hardhatSwapTokens = await swapTokens.deploy(
      hardhatTokenToMint.address,
      hardhatTokenToBurn.address,
      3000,
      3,
      addr2.address
    )
  })

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await hardhatSwapTokens.owner()).to.equal(owner.address)
      await hardhatTokenToBurn.mint(owner.address, 10000000)
      await hardhatTokenToMint.mint(addr1.address, 10000000)
      await hardhatTokenToBurn.mint(addr1.address, 10000000)
      await hardhatTokenToMint.mint(addr2.address, 10000000)
      await hardhatTokenToMint.transferOwnership(hardhatSwapTokens.address)
      await hardhatTokenToBurn.transferOwnership(hardhatSwapTokens.address)
    })
  })

  describe("Exchange Rate", function () {
    it("exchange", async function () {
      await hardhatSwapTokens.exchange(owner.address, 1000)
      const tokenToBurnBalance = await hardhatTokenToBurn.balanceOf(owner.address)
      expect(tokenToBurnBalance).to.equal(9999000)
      const tokenToMintBalance = await hardhatTokenToMint.balanceOf(owner.address)
      expect(tokenToMintBalance).to.equal(3000)
      await hardhatSwapTokens.setRatioDecimals(2)
      await hardhatSwapTokens.exchange(owner.address, 1000)
      const tokenToBurnBalancePost = await hardhatTokenToBurn.balanceOf(owner.address)
      expect(tokenToBurnBalancePost).to.equal(9998000)
      const tokenToMintBalancePost = await hardhatTokenToMint.balanceOf(owner.address)
      expect(tokenToMintBalancePost).to.equal(33000)
    })

    it("exchangeFromExistingHolder", async function () {
      await hardhatSwapTokens.exchangeFromExistingHolder(addr1.address, 1000)
      const tokenToBurnBalanceAddr1 = await hardhatTokenToBurn.balanceOf(addr1.address)
      const tokenToMintBalanceAddr1 = await hardhatTokenToMint.balanceOf(addr1.address)
      const tokenToMintBalanceAddr2 = await hardhatTokenToMint.balanceOf(addr2.address)
      expect(tokenToBurnBalanceAddr1).to.equal(9999000)
      expect(tokenToMintBalanceAddr1).to.equal(10030000)
      expect(tokenToMintBalanceAddr2).to.equal(9970000)
    })
  })
})
