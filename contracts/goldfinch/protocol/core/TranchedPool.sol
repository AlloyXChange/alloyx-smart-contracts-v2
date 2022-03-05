// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../interfaces/ITranchedPool.sol";
import "../../interfaces/IPoolTokens.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TranchedPool is ITranchedPool {
  IPoolTokens private poolToken;
  IERC20 private usdcCoin;

  constructor(address _poolTokenAddress, address _usdcCoinAddress) public {
    poolToken = IPoolTokens(_poolTokenAddress);
    usdcCoin = IERC20(_usdcCoinAddress);
  }

  event DepositMade(
    address indexed owner,
    uint256 indexed tranche,
    uint256 indexed tokenId,
    uint256 amount
  );

  function initialize(
    address _config,
    address _borrower,
    uint256 _juniorFeePercent,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256 _principalGracePeriodInDays,
    uint256 _fundableAt,
    uint256[] calldata _allowedUIDTypes
  ) public override {}

  function setPoolTokens(address _poolTokens) external {
    poolToken = IPoolTokens(_poolTokens);
  }

  function getTranche(uint256 tranche) external view override returns (TrancheInfo memory) {
    return TrancheInfo(0, 0, 0, 0, 0);
  }

  function pay(uint256 amount) external override {}

  function lockJuniorCapital() external override {}

  function lockPool() external override {}

  function initializeNextSlice(uint256 _fundableAt) external override {}

  function totalJuniorDeposits() external view override returns (uint256) {
    return 0;
  }

  function drawdown(uint256 amount) external override {}

  function setFundableAt(uint256 timestamp) external override {}

  function deposit(uint256 tranche, uint256 amount) external override returns (uint256 tokenId) {
    require(amount > 0, "Must deposit > zero");
    IPoolTokens.MintParams memory params = IPoolTokens.MintParams({
      tranche: tranche,
      principalAmount: amount * 100000
    });
    tokenId = poolToken.mint(params, msg.sender);
    usdcCoin.transferFrom(msg.sender, address(this), amount);
    emit DepositMade(msg.sender, tranche, tokenId, amount);
    return tokenId;
  }

  function assess() external override {}

  function depositWithPermit(
    uint256 tranche,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external override returns (uint256 tokenId) {
    return 0;
  }

  function withdraw(uint256 tokenId, uint256 amount)
    external
    override
    returns (uint256 interestWithdrawn, uint256 principalWithdrawn)
  {
    return (0, 0);
  }

  function withdrawMax(uint256 tokenId)
    external
    override
    returns (uint256 interestWithdrawn, uint256 principalWithdrawn)
  {
    return (0, 0);
  }

  function withdrawMultiple(uint256[] calldata tokenIds, uint256[] calldata amounts)
    external
    override
  {}

  /**
   * @notice Determines the amount of interest and principal redeemable by a particular tokenId
   * @param tokenId The token representing the position
   * @return interestRedeemable The interest available to redeem
   * @return principalRedeemable The principal available to redeem
   */
  function availableToWithdraw(uint256 tokenId)
    public
    view
    override
    returns (uint256 interestRedeemable, uint256 principalRedeemable)
  {
    return (tokenId * 1000, tokenId * 10000);
  }
}
