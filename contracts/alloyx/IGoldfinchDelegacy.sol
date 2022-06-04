// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../goldfinch/interfaces/ITranchedPool.sol";
import "../goldfinch/interfaces/ISeniorPool.sol";
import "../goldfinch/interfaces/IPoolTokens.sol";

/**
 * @title Goldfinch Delegacy Interface
 * @notice Middle layer to communicate with goldfinch contracts
 * @author AlloyX
 */
interface IGoldfinchDelegacy {
  /**
   * @notice GoldFinch PoolToken Value in Value in term of USDC
   */
  function getGoldfinchDelegacyBalanceInUSDC() external view returns (uint256);

  /**
   * @notice Claim certain amount of reward token based on alloy silver token, the method will burn the silver token of
   * the amount of message sender, and transfer reward token to message sender
   * @param _rewardee the address of rewardee
   * @param _amount the amount of silver tokens used to claim
   * @param _totalSupply total claimable and claimed silver tokens of all stakeholders
   * @param _percentageFee the earning fee for redeeming silver token in percentage in terms of GFI
   */
  function claimReward(
    address _rewardee,
    uint256 _amount,
    uint256 _totalSupply,
    uint256 _percentageFee
  ) external;

  /**
   * @notice Get gfi amount that should be transfered to the claimer for the amount of CRWN
   * @param _amount the amount of silver tokens used to claim
   * @param _totalSupply total claimable and claimed silver tokens of all stakeholders
   * @param _percentageFee the earning fee for redeeming silver token in percentage in terms of GFI
   */
  function getRewardAmount(
    uint256 _amount,
    uint256 _totalSupply,
    uint256 _percentageFee
  ) external view returns (uint256);

  /**
   * @notice USDC Value in Vault for investment
   */
  function getUSDCBalanceAvailableForInvestment() external view returns (uint256);

  /**
   * @notice Purchase junior token through this delegacy to get pooltoken inside this delegacy
   * @param _amount the amount of usdc to purchase by
   */
  function purchaseJuniorTokenOnBestTranch(uint256 _amount) external;

  /**
   * @notice Purchase junior token through this delegacy to get pooltoken inside this delegacy
   * @param _amount the amount of usdc to purchase by
   * @param _poolAddress the pool address to buy from
   * @param _tranche the tranch id
   */
  function purchaseJuniorToken(
    uint256 _amount,
    address _poolAddress,
    uint256 _tranche
  ) external;

  /**
   * @notice Sell junior token through this delegacy to get repayments
   * @param _tokenId the ID of token to sell
   * @param _amount the amount to withdraw
   * @param _poolAddress the pool address to withdraw from
   * @param _percentageBronzeRepayment the repayment fee for bronze token in percentage
   */
  function sellJuniorToken(
    uint256 _tokenId,
    uint256 _amount,
    address _poolAddress,
    uint256 _percentageBronzeRepayment
  ) external;

  /**
   * @notice Purchase senior token through this delegacy to get FIDU inside this delegacy
   * @param _amount the amount of USDC to purchase by
   */
  function purchaseSeniorTokens(uint256 _amount) external;

  /**
   * @notice Purchase senior token through this delegacy to get FIDU inside this delegacy
   * @param _amount the amount of USDC to purchase by
   * @param _to the receiver of fidu
   */
  function purchaseSeniorTokensAndTransferTo(uint256 _amount, address _to) external;

  /**
   * @notice sell senior token through delegacy to redeem fidu
   * @param _amount the amount of fidu to sell
   * @param _percentageBronzeRepayment the repayment fee for bronze token in percentage
   */
  function sellSeniorTokens(uint256 _amount, uint256 _percentageBronzeRepayment) external;

  /**
   * @notice Validates the Pooltoken to be deposited and get the USDC value of the token
   * @param _tokenAddress the Pooltoken address
   * @param _depositor the person to deposit
   * @param _tokenID the ID of the Pooltoken
   */
  function validatesTokenToDepositAndGetPurchasePrice(
    address _tokenAddress,
    address _depositor,
    uint256 _tokenID
  ) external returns (uint256);

  /**
   * @notice Pay USDC tokens to account
   * @param _to the address to pay to
   * @param _amount the amount to pay
   */
  function payUsdc(address _to, uint256 _amount) external;

  /**
   * @notice Approve certain amount token of certain address to some other account
   * @param _account the address to approve
   * @param _amount the amount to approve
   * @param _tokenAddress the token address to approve
   */
  function approve(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external;
}
