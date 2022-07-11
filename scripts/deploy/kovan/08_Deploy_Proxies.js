const { getNamedAccounts, deployments, network, run, artifacts } = require("hardhat")
const {
  networkConfig,
  developmentChains,
  VERIFICATION_BLOCK_CONFIRMATIONS,
} = require("../helper-hardhat-config")
const { verify } = require("../helper-functions")
const path = require("path")
const fs = require("fs")

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  const deployProxyContract = async (contractName, ...params) => {
    const contractFactory = await ethers.getContractFactory(contractName)
    const contract = await upgrades.deployProxy(contractFactory, [...params], {
      timeout: 6000000,
    })
    await contract.deployed()
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(contract.address)
    const abi = await artifacts.readArtifact(contractName)
    const address = contract.address
    const jsonToExport = { address, ...abi }
    const jsonString = JSON.stringify(jsonToExport, null, 2)
    const exportPath =
      path.resolve(__dirname) + `/../deployments/${network.name}/${contractName}.json`
    fs.writeFile(exportPath, jsonString, function (err) {
      if (err) throw err
      console.log("File is created successfully.")
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
      log("Verifying...")
      await verify(implementationAddress, [])
    }
    return contract
  }

  const dura = await deployProxyContract("AlloyxTokenDURA")
  const crwn = await deployProxyContract("AlloyxTokenCRWN")

  const alloyxConfig = await deployProxyContract("AlloyxConfig")

  const alloyxStakeInfo = await deployProxyContract("AlloyxStakeInfo",alloyxConfig.address)
  const goldfinchDesk = await deployProxyContract("GoldfinchDesk",alloyxConfig.address)
  const stableCoinDesk = await deployProxyContract("StableCoinDesk",alloyxConfig.address)
  const stakeDesk = await deployProxyContract("StakeDesk",alloyxConfig.address)
  const alloyxTreasury = await deployProxyContract("AlloyxTreasury",alloyxConfig.address)
  const alloyxExchange = await deployProxyContract("AlloyxExchange",alloyxConfig.address)
}

module.exports.tags = ["all", "feed", "main"]
