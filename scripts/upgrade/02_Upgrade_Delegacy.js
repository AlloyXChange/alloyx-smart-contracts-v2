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
}

module.exports.tags = ["all", "feed", "main"]
