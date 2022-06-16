const { getNamedAccounts, deployments, network, run } = require("hardhat")
const {
  networkConfig,
  developmentChains,
  VERIFICATION_BLOCK_CONFIRMATIONS,
} = require("../helper-hardhat-config")
const { verify } = require("../helper-functions")

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  // Deploy DURA, it will deploy proxyAdmin if not exist in /.openzeppelin, new proxy contract and implementation contract if not exist in /.openzeppelin
  const duraContract = await ethers.getContractFactory("AlloyxTokenDURA")
  const dura = await upgrades.deployProxy(duraContract, [])
  await dura.deployed()
  const duraImplementationAddress = await upgrades.erc1967.getImplementationAddress(dura.address)

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(duraImplementationAddress, [])
  }

  // Deploy CRWN
  const crwnContract = await ethers.getContractFactory("AlloyxTokenCRWN")
  const crwn = await upgrades.deployProxy(crwnContract, [])
  await crwn.deployed()
  const crwnImplementationAddress = await upgrades.erc1967.getImplementationAddress(crwn.address)

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(crwnImplementationAddress, [])
  }

  // Deploy GoldfinchDelegacy
  let fidu = await get("FIDU")
  let gfi = await get("GFI")
  let usdc = await get("USDC")
  let poolTokens = await get("PoolTokens")
  let seniorPool = await get("SeniorPool")
  let sortedGoldfinchTranches = await get("SortedGoldfinchTranches")
  const delegacyContract = await ethers.getContractFactory("GoldfinchDelegacy")
  const delegacy = await upgrades.deployProxy(delegacyContract, [
    usdc.address,
    fidu.address,
    gfi.address,
    poolTokens.address,
    seniorPool.address,
    "0x0000000000000000000000000000000000000000",
    sortedGoldfinchTranches.address,
  ])
  await delegacy.deployed()
  const delegacyImplementationAddress = await upgrades.erc1967.getImplementationAddress(
    delegacy.address
  )

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(delegacyImplementationAddress, [])
  }

  // Deploy Vault
  let uid = await get("UID")
  const vaultContract = await ethers.getContractFactory("AlloyxVault")
  const vault = await upgrades.deployProxy(vaultContract, [
    dura.address,
    crwn.address,
    usdc.address,
    delegacy.address,
    uid.address,
  ])
  await vault.deployed()
  const vaultImplementationAddress = await upgrades.erc1967.getImplementationAddress(vault.address)

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(vaultImplementationAddress, [])
  }
}

module.exports.tags = ["all", "feed", "main"]
