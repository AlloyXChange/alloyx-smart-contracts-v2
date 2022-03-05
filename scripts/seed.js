/* eslint-disable no-process-exit */
// yarn hardhat run scripts/seed.js --network kovan
const { ethers } = require("hardhat")

async function seed() {
  const fidu = await ethers.getContract("FIDU")
  const accounts = await ethers.getSigners()
  const seniorPool = await ethers.getContract("SeniorPool")
  const usdc = await ethers.getContract("USDC")
  await usdc.mint(accounts[0].address, ethers.BigNumber.from(1e18.toString()))
  let alloyxBronzeToken = await ethers.getContract("AlloyxTokenBronze")
  await alloyxBronzeToken.mint(accounts[0].address, ethers.BigNumber.from(1e18.toString()))
  let alloyxSilverToken = await ethers.getContract("AlloyxTokenSilver")
  await alloyxSilverToken.mint(accounts[0].address, ethers.BigNumber.from(1e18.toString()))
  let alloyVault = await ethers.getContract("AlloyVault")
  await usdc.mint(alloyVault.address, ethers.BigNumber.from(1e18.toString()))
  let ownerOfAlloyxBronze = await alloyxBronzeToken.owner()
  let ownerOfAlloyxSilver = await alloyxSilverToken.owner()
  let ownerOfFIDU = await fidu.owner()
  if (ownerOfAlloyxBronze !== alloyVault.address) {
    await alloyxBronzeToken.transferOwnership(alloyVault.address)
  }
  if (ownerOfAlloyxSilver !== alloyVault.address) {
    await alloyxSilverToken.transferOwnership(alloyVault.address)
  }
  if (ownerOfFIDU !== seniorPool.address) {
    await fidu.transferOwnership(alloyVault.address)
  }
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
