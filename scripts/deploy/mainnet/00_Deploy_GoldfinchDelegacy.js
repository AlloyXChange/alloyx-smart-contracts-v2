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
  const usdcAddress = ""
  const fiduAddress = ""
  const gfiAddress = ""
  const poolTokenAddress = ""
  const seniorPoolAddress = ""
  log("----------------------------------------------------")
  const alloy = await deploy("GoldfinchDelegacy", {
    from: deployer,
    args: [
      usdcAddress,
      fiduAddress,
      gfiAddress,
      poolTokenAddress,
      seniorPoolAddress,
      "0x0000000000000000000000000000000000000000",
    ],
    log: true,
    waitConfirmations: waitBlockConfirmations,
  })

  // Verify the deployment
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(alloy.address, [
      usdcAddress,
      fiduAddress,
      gfiAddress,
      poolTokenAddress,
      seniorPoolAddress,
      "0x0000000000000000000000000000000000000000",
    ])
  }
}

module.exports.tags = ["all", "feed", "main"]
