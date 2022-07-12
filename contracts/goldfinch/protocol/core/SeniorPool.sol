// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../interfaces/ISeniorPool.sol";
import "../../interfaces/IPoolTokens.sol";
import "../../../alloyx/test/FIDU.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Goldfinch's SeniorPool contract
 * @notice Main entry point for senior LPs (a.k.a. capital providers)
 *  Automatically invests across borrower pools using an adjustable strategy.
 * @author Goldfinch
 */
contract SeniorPool is ISeniorPool {
  using SafeMath for uint256;
  FIDU private fiduCoin;
  IERC20 private usdcCoin;

  event DepositMade(address indexed capitalProvider, uint256 amount, uint256 shares);

  constructor(
    uint256 _sharePrice,
    address _fiduCoinAddress,
    address _usdcCoinAddress
  ) public {
    sharePrice = _sharePrice;
    fiduCoin = FIDU(_fiduCoinAddress);
    usdcCoin = IERC20(_usdcCoinAddress);
  }

  function setSharePrice(uint256 _sharePrice) external {
    sharePrice = _sharePrice;
  }

  /**
   * @notice Deposits `amount` USDC from msg.sender into the SeniorPool, and grants you the
   *  equivalent value of FIDU tokens
   * @param amount The amount of USDC to deposit
   */
  function deposit(uint256 amount) public override returns (uint256 depositShares) {
    require(amount > 0, "Must deposit more than zero");
    // Check if the amount of new shares to be added is within limits
    depositShares = getNumShares(amount);
    emit DepositMade(msg.sender, amount, depositShares);
    bool success = doUSDCTransfer(msg.sender, address(this), amount);
    usdcCoin.approve(address(this), amount);
    require(success, "Failed to transfer for deposit");
    fiduCoin.mint(msg.sender, depositShares);
    return depositShares;
  }

  function doUSDCTransfer(
    address from,
    address to,
    uint256 amount
  ) internal returns (bool) {
    require(to != address(0), "Can't send to zero address");
    return usdcCoin.transferFrom(from, to, amount);
  }

  function depositWithPermit(
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external override returns (uint256 depositShares) {
    return 0;
  }

  function withdraw(uint256 usdcAmount) external override returns (uint256 amount) {
    return 0;
  }

  function withdrawInFidu(uint256 fiduAmount) external override returns (uint256 amount) {
    require(fiduAmount > 0, "Must withdraw more than zero");
    uint256 usdcAmount = getUSDCAmountFromShares(fiduAmount);
    uint256 withdrawShares = fiduAmount;
    return _withdraw(usdcAmount, withdrawShares);
  }

  function _withdraw(uint256 usdcAmount, uint256 withdrawShares)
    internal
    returns (uint256 userAmount)
  {
    uint256 currentShares = fiduCoin.balanceOf(msg.sender);
    require(
      withdrawShares <= currentShares,
      "Amount requested is greater than what this address owns"
    );

    // Send the amounts
    bool success = doUSDCTransfer(address(this), msg.sender, usdcAmount);

    fiduCoin.burn(msg.sender, withdrawShares);
    return usdcAmount;
  }

  function sweepToCompound() public override {}

  function sweepFromCompound() public override {}

  function invest(ITranchedPool pool) public override {}

  function estimateInvestment(ITranchedPool pool) public view override returns (uint256) {
    return 0;
  }

  function redeem(uint256 tokenId) public override {}

  function writedown(uint256 tokenId) public override {}

  function calculateWritedown(uint256 tokenId)
    public
    view
    override
    returns (uint256 writedownAmount)
  {
    return 0;
  }

  function assets() public view override returns (uint256) {
    return 0;
  }

  /**
   * @notice Converts and USDC amount to FIDU amount
   * @param _amount USDC amount to convert to FIDU
   */
  function getNumShares(uint256 _amount) public view override returns (uint256) {
    return usdcToFidu(_amount).mul(fiduMantissa()).div(sharePrice);
  }

  function usdcToFidu(uint256 amount) internal pure returns (uint256) {
    return amount.mul(fiduMantissa()).div(usdcMantissa());
  }

  function getUSDCAmountFromShares(uint256 fiduAmount) internal view returns (uint256) {
    return fiduToUSDC(fiduAmount.mul(sharePrice).div(fiduMantissa()));
  }

  function fiduToUSDC(uint256 amount) internal pure returns (uint256) {
    return amount.div(fiduMantissa().div(usdcMantissa()));
  }

  function totalShares() internal view returns (uint256) {
    return fiduCoin.totalSupply();
  }

  function fiduMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(18);
  }

  function usdcMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(6);
  }
}
