// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IAlloyxTreasury {
  function addEarningGfiFee(uint256 _amount) external;

  function addRepaymentFee(uint256 _amount) external;

  function addRedemptionFee(uint256 _amount) external;

  function addDuraToFiduFee(uint256 _amount) external;

  function getEarningGfiFee() external view returns (uint256);

  /**
   * @notice Alloy DURA Token Value in terms of USDC
   */
  function getTreasuryTotalBalanceInUSDC() external view returns (uint256);

  /**
   * @notice Convert Alloyx DURA to USDC amount
   * @param _amount the amount of DURA token to convert to usdc
   */
  function alloyxDURAToUSDC(uint256 _amount) external view returns (uint256);

  /**
   * @notice Convert USDC Amount to Alloyx DURA
   * @param _amount the amount of usdc to convert to DURA token
   */
  function usdcToAlloyxDURA(uint256 _amount) external view returns (uint256);

  /**
   * @notice Transfer certain amount token of certain address to some other account
   * @param _account the address to transfer
   * @param _amount the amount to transfer
   * @param _tokenAddress the token address to transfer
   */
  function transferERC20(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external;

  /**
   * @notice Transfer certain amount token of certain address to some other account
   * @param _account the address to transfer
   * @param _tokenId the token ID to transfer
   * @param _tokenAddress the token address to transfer
   */
  function transferERC721(
    address _tokenAddress,
    address _account,
    uint256 _tokenId
  ) external ;

  /**
   * @notice Approve certain amount token of certain address to some other account
   * @param _account the address to approve
   * @param _amount the amount to approve
   * @param _tokenAddress the token address to approve
   */
  function approveERC20(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external ;

  /**
   * @notice Approve certain amount token of certain address to some other account
   * @param _account the address to approve
   * @param _tokenId the token ID to transfer
   * @param _tokenAddress the token address to approve
   */
  function approveERC721(
    address _tokenAddress,
    address _account,
    uint256 _tokenId
  ) external ;
}
