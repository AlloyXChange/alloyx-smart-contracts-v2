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

  let fidu = await get("FIDU")
  let gfi = await get("GFI")
  let usdc = await get("USDC")
  let poolTokens = await get("PoolTokens")
  let seniorPool = await get("SeniorPool")
  let sortedGoldfinchTranches = await get("SortedGoldfinchTranches")
  const delegacy = await deployProxyContract(
    "GoldfinchDelegacy",
    usdc.address,
    fidu.address,
    gfi.address,
    poolTokens.address,
    seniorPool.address,
    "0x0000000000000000000000000000000000000000",
    sortedGoldfinchTranches.address
  )

  console.log(dura.address)
  console.log(crwn.address)
  console.log(delegacy.address)

  let uid = await get("UID")
  let alloyxStakeInfo = await get("AlloyxStakeInfo")
  console.log(alloyxStakeInfo.address)
  await deployProxyContract(
    "AlloyxVault",
    dura.address,
    crwn.address,
    usdc.address,
    delegacy.address,
    alloyxStakeInfo.address,
    uid.address
  )
}

module.exports.tags = ["all", "feed", "main"]
