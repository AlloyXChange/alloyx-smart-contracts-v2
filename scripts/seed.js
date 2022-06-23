/* eslint-disable no-process-exit */
// yarn hardhat run scripts/seed.js --network kovan
const { ethers, network } = require("hardhat")
const fs = require("fs")
const path = require("path")

async function getContract(contractName) {
  const exportPath =
    path.resolve(__dirname) + `/../deployments/${network.name}/${contractName}.json`
  let data = fs.readFileSync(exportPath)
  let contractAbi = JSON.parse(data)
  let contract = await ethers.getContractAt(contractName, contractAbi.address)
  return contract
}

async function seed() {
  try {
    const fidu = await getContract("FIDU")
    const gfi = await getContract("GFI")
    const accounts = await ethers.getSigners()
    const seniorPool = await getContract("SeniorPool")
    const poolTokens = await getContract("PoolTokens")
    const tranchedPool = await getContract("TranchedPool")
    const usdc = await getContract("USDC")
    const alloyxStakeInfo = await getContract("AlloyxStakeInfo")
    await usdc.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    await gfi.mint(accounts[0].address, ethers.utils.parseEther("1000"))

    await poolTokens.setPoolAddress(tranchedPool.address)
    let alloyxBronzeToken = await getContract("AlloyxTokenDURA")
    if ((await alloyxBronzeToken.owner()) === accounts[0].address) {
      await alloyxBronzeToken.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    }
    let alloyxSilverToken = await getContract("AlloyxTokenCRWN")
    if ((await alloyxSilverToken.owner()) === accounts[0].address) {
      await alloyxSilverToken.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    }
    let alloyVault = await getContract("AlloyxVault")
    let goldfinchDelegacy = await getContract("GoldfinchDelegacy")
    await alloyVault.changeGoldfinchDelegacyAddress(goldfinchDelegacy.address)
    await goldfinchDelegacy.changeVaultAddress(alloyVault.address)
    if ((await usdc.owner()) === accounts[0].address) {
      await usdc.mint(alloyVault.address, ethers.utils.parseEther("1000"))
    }
    await alloyxStakeInfo.changeVaultAddress(alloyVault.address)
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
      await fidu.transferOwnership(seniorPool.address)
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
