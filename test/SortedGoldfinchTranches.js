const { expect } = require("chai")

describe("SortedGoldfinchTranches contract", function () {
  let tranches
  let hardhatTranches
  let owner
  let addr1
  let addr2
  let addrs

  before(async function () {
    tranches = await ethers.getContractFactory("SortedGoldfinchTranches")
    ;[owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    hardhatTranches = await tranches.deploy()
  })

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await hardhatTranches.owner()).to.equal(owner.address)
    })
  })

  describe("Transactions", function () {
    it("addTranch: add tranch and score", async function () {
      await hardhatTranches.addTranch(1, 1)
      await hardhatTranches.addTranch(2, 2)
      await hardhatTranches.addTranch(3, 3)
      await hardhatTranches.addTranch(5, 5)
      await hardhatTranches.addTranch(4, 4)
      const top3 = await hardhatTranches.getTop(3)
      expect(top3[0]).to.equal(5)
      expect(top3[1]).to.equal(4)
      expect(top3[2]).to.equal(3)
    })
    it("increaseScore: increase tranch by score", async function () {
      await hardhatTranches.increaseScore(1, 6)
      const top3 = await hardhatTranches.getTop(3)
      expect(top3[0]).to.equal(1)
      expect(top3[1]).to.equal(5)
      expect(top3[2]).to.equal(4)
    })
    it("reduceScore: increase tranch by score", async function () {
      await hardhatTranches.reduceScore(1, 5)
      const top3 = await hardhatTranches.getTop(3)
      expect(top3[0]).to.equal(5)
      expect(top3[1]).to.equal(4)
      expect(top3[2]).to.equal(3)
    })
    it("updateScore: update tranch to score", async function () {
      await hardhatTranches.updateScore(1, 6)
      const top3 = await hardhatTranches.getTop(3)
      expect(top3[0]).to.equal(1)
      expect(top3[1]).to.equal(5)
      expect(top3[2]).to.equal(4)
    })
    it("removeTranch: remove tranch", async function () {
      await hardhatTranches.removeTranch(1)
      const top3 = await hardhatTranches.getTop(3)
      const listSize = await hardhatTranches.listSize()
      expect(top3[0]).to.equal(5)
      expect(top3[1]).to.equal(4)
      expect(top3[2]).to.equal(3)
      expect(listSize).to.equal(4)
    })
  })
})
