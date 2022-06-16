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

  // Deploy DURA, it will deploy implementation contract under the proxy defined
  const DURA_PROXY = "0xFC84e64628B302e63d4Af566Dc0015E27fe75C16"
  const duraContract = await ethers.getContractFactory("AlloyxTokenDURA")
  const dura = await upgrades.upgradeProxy(DURA_PROXY, duraContract)
  await dura.deployed()
  const duraImplementationAddress = await upgrades.erc1967.getImplementationAddress(dura.address)

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(duraImplementationAddress, [])
  }

  // Deploy CRWN
  const CRWN_PROXY = "0xFC84e64628B302e63d4Af566Dc0015E27fe75C16"
  const crwnContract = await ethers.getContractFactory("AlloyxTokenCRWN")
  const crwn = await upgrades.upgradeProxy(CRWN_PROXY, crwnContract)
  await crwn.deployed()
  const crwnImplementationAddress = await upgrades.erc1967.getImplementationAddress(crwn.address)

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(crwnImplementationAddress, [])
  }

  // Deploy GoldfinchDelegacy
  const DELEGACY_PROXY = "0xFC84e64628B302e63d4Af566Dc0015E27fe75C16"
  const delegacyContract = await ethers.getContractFactory("GoldfinchDelegacy")
  const delegacy = await upgrades.upgradeProxy(DELEGACY_PROXY, delegacyContract)
  await delegacy.deployed()
  const delegacyImplementationAddress = await upgrades.erc1967.getImplementationAddress(
    delegacy.address
  )

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(delegacyImplementationAddress, [])
  }

  // Deploy Vault
  const VAULT_PROXY = "0xFC84e64628B302e63d4Af566Dc0015E27fe75C16"
  const vaultContract = await ethers.getContractFactory("AlloyxVault")
  const vault = await upgrades.upgradeProxy(VAULT_PROXY, vaultContract)
  await vault.deployed()
  const vaultImplementationAddress = await upgrades.erc1967.getImplementationAddress(vault.address)

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(vaultImplementationAddress, [])
  }
}

module.exports.tags = ["all", "feed", "main"]
