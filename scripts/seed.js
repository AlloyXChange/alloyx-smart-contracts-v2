/* eslint-disable no-process-exit */
// yarn hardhat run scripts/seed.js --network kovan
const { ethers } = require("hardhat")

async function seed() {
  try {
    const fidu = await ethers.getContract("FIDU")
    const accounts = await ethers.getSigners()
    const seniorPool = await ethers.getContract("SeniorPool")
    const usdc = await ethers.getContract("USDC")
    await usdc.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    let alloyxBronzeToken = await ethers.getContract("AlloyxTokenDURA")
    if ((await alloyxBronzeToken.owner()) === accounts[0].address) {
      await alloyxBronzeToken.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    }
    let alloyxSilverToken = await ethers.getContract("AlloyxTokenCRWN")
    if ((await alloyxSilverToken.owner()) === accounts[0].address) {
      await alloyxSilverToken.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    }
    let alloyVault = await ethers.getContract("AlloyxVaultV4_0")
    if ((await usdc.owner()) === accounts[0].address) {
      await usdc.mint(alloyVault.address, ethers.utils.parseEther("1000"))
    }
    let ownerOfAlloyxBronze = await alloyxBronzeToken.owner()
    let ownerOfAlloyxSilver = await alloyxSilverToken.owner()
    let ownerOfFIDU = await fidu.owner()
    if (ownerOfAlloyxBronze !== alloyVault.address && ownerOfAlloyxBronze === accounts[0].address) {
      await alloyxBronzeToken.transferOwnership(alloyVault.address)
    }
    if (ownerOfAlloyxSilver !== alloyVault.address && ownerOfAlloyxSilver === accounts[0].address) {
      await alloyxSilverToken.transferOwnership(alloyVault.address)
    }
    if (ownerOfFIDU !== seniorPool.address && ownerOfFIDU === accounts[0].address) {
      await fidu.transferOwnership(alloyVault.address)
    }
    if ((await alloyVault.owner()) === accounts[0].address) {
      await alloyVault.startVaultOperation()
    }
  } catch (err) {
    console.log(err)
  }
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
