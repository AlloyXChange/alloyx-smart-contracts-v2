const { expect } = require("chai")

describe("SortedGoldfinchTranches contract", function () {
  let tranches
  let hardhatTranches
  let owner
  let addr1
  let addr2
  let addr3
  let addr4
  let addr5
  let addrs

  before(async function () {
    tranches = await ethers.getContractFactory("SortedGoldfinchTranches")
    ;[owner, addr1, addr2, addr3, addr4, addr5, ...addrs] = await ethers.getSigners()

    hardhatTranches = await tranches.deploy()
  })

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await hardhatTranches.owner()).to.equal(owner.address)
    })
  })

  describe("Transactions", function () {
    it("addTranch: add tranch and score", async function () {
      await hardhatTranches.addTranch(addr1.address, 1)
      await hardhatTranches.addTranch(addr2.address, 2)
      await hardhatTranches.addTranch(addr3.address, 3)
      await hardhatTranches.addTranch(addr5.address, 5)
      await hardhatTranches.addTranch(addr4.address, 4)
      const top3 = await hardhatTranches.getTop(3)
      expect(top3[0]).to.equal(addr5.address)
      expect(top3[1]).to.equal(addr4.address)
      expect(top3[2]).to.equal(addr3.address)
    })
    it("increaseScore: increase tranch by score", async function () {
      await hardhatTranches.increaseScore(addr1.address, 6)
      const top3 = await hardhatTranches.getTop(3)
      expect(top3[0]).to.equal(addr1.address)
      expect(top3[1]).to.equal(addr5.address)
      expect(top3[2]).to.equal(addr4.address)
    })
    it("reduceScore: increase tranch by score", async function () {
      await hardhatTranches.reduceScore(addr1.address, 5)
      const top3 = await hardhatTranches.getTop(3)
      expect(top3[0]).to.equal(addr5.address)
      expect(top3[1]).to.equal(addr4.address)
      expect(top3[2]).to.equal(addr3.address)
    })
    it("updateScore: update tranch to score", async function () {
      await hardhatTranches.updateScore(addr1.address, 6)
      const top3 = await hardhatTranches.getTop(3)
      expect(top3[0]).to.equal(addr1.address)
      expect(top3[1]).to.equal(addr5.address)
      expect(top3[2]).to.equal(addr4.address)
    })
    it("removeTranch: remove tranch", async function () {
      await hardhatTranches.removeTranch(addr1.address)
      const top3 = await hardhatTranches.getTop(3)
      const listSize = await hardhatTranches.listSize()
      expect(top3[0]).to.equal(addr5.address)
      expect(top3[1]).to.equal(addr4.address)
      expect(top3[2]).to.equal(addr3.address)
      expect(listSize).to.equal(4)
    })
  })
})
