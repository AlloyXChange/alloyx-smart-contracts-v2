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

}

module.exports.tags = ["all", "feed", "main"]
