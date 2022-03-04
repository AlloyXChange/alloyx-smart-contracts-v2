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

  let usdc = await get("USDC")

  log("----------------------------------------------------")
  const tranchedPool = await deploy("TranchedPool", {
    from: deployer,
    args: ["0x0000000000000000000000000000000000000000",usdc.address],
    log: true,
    waitConfirmations: waitBlockConfirmations,
  })

  // Verify the deployment
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(tranchedPool.address, ["0x0000000000000000000000000000000000000000",usdc.address])
  }
}

module.exports.tags = ["all", "feed", "main"]
