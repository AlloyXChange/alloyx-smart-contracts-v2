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
    // await usdc.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    // await gfi.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    console.log("gfi")
    await poolTokens.setPoolAddress(tranchedPool.address)
    let alloyxBronzeToken = await getContract("AlloyxTokenDURA")
    // await alloyxBronzeToken.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    let alloyxSilverToken = await getContract("AlloyxTokenCRWN")
    // await alloyxSilverToken.mint(accounts[0].address, ethers.utils.parseEther("1000"))
    const goldfinchDesk = await getContract("GoldfinchDesk")
    const stableCoinDesk = await getContract("StableCoinDesk")
    const stakeDesk = await getContract("StakeDesk")
    const whitelist = await getContract("AlloyxWhitelist")
    const sortedGoldfinchTranches = await getContract("SortedGoldfinchTranches")
    console.log("sortedGoldfinchTranches")
    const treasury = await getContract("AlloyxTreasury")
    const exchange = await getContract("AlloyxExchange")

    const config = await getContract("AlloyxConfig")
    // await config.setAddress(0, treasury.address)
    // await config.setAddress(1, exchange.address)
    // await config.setAddress(2, config.address)
    // await config.setAddress(3, goldfinchDesk.address)
    // await config.setAddress(4, stableCoinDesk.address)
    // await config.setAddress(5, stakeDesk.address)
    // await config.setAddress(6, whitelist.address)
    // await config.setAddress(7, alloyxStakeInfo.address)
    // await config.setAddress(8, poolTokens.address)
    // await config.setAddress(9, seniorPool.address)
    // await config.setAddress(10, sortedGoldfinchTranches.address)
    // await config.setAddress(11, fidu.address)
    // await config.setAddress(12, gfi.address)
    // await config.setAddress(13, usdc.address)
    // await config.setAddress(14, alloyxBronzeToken.address)
    // await config.setAddress(15, alloyxSilverToken.address)
    //
    // await config.setNumber(0, 1)
    // await config.setNumber(1, 1)
    // await config.setNumber(2, 2)
    // await config.setNumber(3, 10)
    // await config.setNumber(4, 1)
    // await config.setNumber(6, 2)

    await alloyxSilverToken.addAdmin(goldfinchDesk.address)
    await alloyxSilverToken.addAdmin(stableCoinDesk.address)
    await alloyxSilverToken.addAdmin(stakeDesk.address)
    await alloyxBronzeToken.addAdmin(goldfinchDesk.address)
    await alloyxBronzeToken.addAdmin(stableCoinDesk.address)
    await alloyxBronzeToken.addAdmin(stakeDesk.address)
    await treasury.addAdmin(goldfinchDesk.address)
    await treasury.addAdmin(stableCoinDesk.address)
    await treasury.addAdmin(stakeDesk.address)
    await alloyxStakeInfo.addAdmin(goldfinchDesk.address)
    await alloyxStakeInfo.addAdmin(stableCoinDesk.address)
    await alloyxStakeInfo.addAdmin(stakeDesk.address)
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
