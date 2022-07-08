// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title ConfigOptions
 * @notice A central place for enumerating the configurable options of our AlloyxConfig contract
 * @author AlloyX
 */

library ConfigOptions {
  // NEVER EVER CHANGE THE ORDER OF THESE!
  // You can rename or append. But NEVER change the order.
  enum Numbers {
    PercentageDURARedemption,
    PercentageDuraToFiduFee,
    PercentageDURARepayment,
    PercentageCRWNEarning,
    PercentageJuniorRedemption,
    PercentageInvestJunior,
    PercentageRewardPerYear
  }
  enum Addresses {
    Treasury,
    Config,
    GoldfinchDesk,
    StableCoinDesk,
    StakeDesk,
    Whitelist,
    AlloyxStakeInfo,
    PoolTokens,
    SeniorPool,
    SortedGoldfinchTranches,
    FIDU,
    GFI,
    USDC,
    DURA,
    CRWN
  }
}
