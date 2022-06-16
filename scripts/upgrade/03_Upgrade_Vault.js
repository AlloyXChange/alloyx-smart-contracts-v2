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
