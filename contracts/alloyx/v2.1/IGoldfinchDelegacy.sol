// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../goldfinch/interfaces/ITranchedPool.sol";
import "../../goldfinch/interfaces/ISeniorPool.sol";
import "../AlloyxTokenBronze.sol";
import "../../goldfinch/interfaces/IPoolTokens.sol";

/**
 * @title Goldfinch Delegacy Interface
 * @notice Middle layer to communicate with goldfinch contracts
 * @author AlloyX
 */
interface IGoldfinchDelegacy {
  function getGoldfinchDelegacyBalanceInUSDC() external view returns (uint256);

  function purchaseJuniorToken(
    uint256 amount,
    address poolAddress,
    uint256 tranche
  ) external;

  function purchaseSeniorTokens(uint256 amount) external;

  function validatesTokenToDepositAndGetPurchasePrice(
    address _tokenAddress,
    address _depositor,
    uint256 _tokenID
  ) external returns (uint256);

  function payUsdc(address _to, uint256 _amount) external;
}
