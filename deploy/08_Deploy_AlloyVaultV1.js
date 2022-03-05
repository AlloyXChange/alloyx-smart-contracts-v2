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

  // Price Feed Address, values can be obtained at https://docs.chain.link/docs/reference-contracts
  // Default one below is ETH/USD contract on Kovan
  const waitBlockConfirmations = developmentChains.includes(network.name)
    ? 1
    : VERIFICATION_BLOCK_CONFIRMATIONS
  let fidu = await get("FIDU")
  let gfi = await get("GFI")
  let usdc = await get("USDC")
  let alloyxToken = await get("AlloyxTokenBronze")

  log("----------------------------------------------------")
  const alloy = await deploy("AlloyxVault", {
    from: deployer,
    args: [alloyxToken.address, usdc.address, fidu.address, gfi.address],
    log: true,
    waitConfirmations: waitBlockConfirmations,
  })

  // Verify the deployment
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(alloy.address, [alloyxToken.address, usdc.address, fidu.address, gfi.address])
  }
}

module.exports.tags = ["all", "feed", "main"]
