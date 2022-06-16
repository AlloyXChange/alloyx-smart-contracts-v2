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

}

module.exports.tags = ["all", "feed", "main"]
