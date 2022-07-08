// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./ConfigHelper.sol";
import "./AlloyxConfig.sol";

/**
 * @title Goldfinch Delegacy
 * @notice Middle layer to communicate with goldfinch contracts
 * @author AlloyX
 */
contract StableCoinDesk is IStableCoinDesk, AccessControlUpgradeable {
  using SafeMath for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  AlloyxConfig public config;
  using ConfigHelper for AlloyxConfig;

  event Mint(address _tokenReceiver, uint256 _tokenAmount);
  event Burn(address _tokenReceiver, uint256 _tokenAmount);
  event Stake(address _staker, uint256 _amount);
  event DepositDURA(address _tokenSender, uint256 _tokenAmount);
  event DepositStable(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event AlloyxConfigUpdated(address indexed who, address configAddress);

  /**
   * @notice If address is whitelisted
   * @param _address The address to verify.
   */
  modifier isWhitelisted(address _address) {
    require(config.getWhitelist().isUserWhitelisted(_address), "user is not whitelisted");
    _;
  }

  function initialize(address _configAddress) public initializer {
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    config = AlloyxConfig(_configAddress);
  }

  function updateConfig() external onlyRole(DEFAULT_ADMIN_ROLE) {
    config = AlloyxConfig(config.configAddress());
    emit AlloyxConfigUpdated(msg.sender, address(config));
  }

  /**
   * @notice An Alloy token holder can deposit their tokens and redeem them for USDC
   * @param _tokenAmount Number of Alloy Tokens
   */
  function depositAlloyxDURATokens(uint256 _tokenAmount) external isWhitelisted(msg.sender) {
    uint256 amountToWithdraw = config.getTreasury().alloyxDURAToUSDC(_tokenAmount);
    uint256 withdrawalFee = amountToWithdraw.mul(config.getPercentageDURARedemption()).div(100);
    config.getDURA().burn(msg.sender, _tokenAmount);
    config.getTreasury().transferERC20(
      config.usdcAddress(),
      msg.sender,
      amountToWithdraw.sub(withdrawalFee)
    );
    config.getTreasury().addRedemptionFee(withdrawalFee);
    emit DepositDURA(msg.sender, _tokenAmount);
    emit Burn(msg.sender, _tokenAmount);
  }

  /**
   * @notice A Liquidity Provider can deposit supported stable coins for Alloy Tokens
   * @param _tokenAmount Number of stable coin
   * @param _toStake whether to stake the dura
   */
  function depositUSDCCoin(uint256 _tokenAmount, bool _toStake) external isWhitelisted(msg.sender) {
    uint256 amountToMint = config.getTreasury().usdcToAlloyxDURA(_tokenAmount);
    config.getUSDC().safeTransferFrom(msg.sender, config.treasuryAddress(), _tokenAmount);
    config.getDURA().mint(msg.sender, amountToMint);
    if (_toStake) {
      config.getDURA().mint(address(this), amountToMint);
      config.getAlloyxStakeInfo().addStake(msg.sender, amountToMint);
      emit Mint(address(this), amountToMint);
      emit Stake(msg.sender, amountToMint);
    } else {
      config.getDURA().mint(msg.sender, amountToMint);
      emit Mint(msg.sender, amountToMint);
    }
    emit DepositStable(config.usdcAddress(), msg.sender, amountToMint);
  }
}
