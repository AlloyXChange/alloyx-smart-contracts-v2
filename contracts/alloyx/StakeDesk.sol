// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ConfigHelper.sol";
import "./AlloyxConfig.sol";

/**
 * @title Goldfinch Delegacy
 * @notice Middle layer to communicate with goldfinch contracts
 * @author AlloyX
 */
contract StableCoinDesk is IStableCoinDesk, AccessControlUpgradeable {
  using SafeMath for uint256;

  AlloyxConfig public config;
  using ConfigHelper for AlloyxConfig;

  event Reward(address _tokenReceiver, uint256 _tokenAmount);
  event Claim(address _tokenReceiver, uint256 _tokenAmount);
  event AlloyxConfigUpdated(address indexed who, address configAddress);

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
   * @notice Total claimable and claimed CRWN tokens of all stakeholders
   */
  function totalClaimableAndClaimedCRWNToken() public view returns (uint256) {
    return
      config.getAlloyxStakeInfo().totalClaimableCRWNToken().add(config.getCRWN().totalSupply());
  }

  /**
   * @notice Claim all alloy CRWN tokens of the message sender, the method will mint the CRWN token of the claimable
   * amount to message sender, and clear the past rewards to zero
   */
  function claimAllAlloyxCRWN() external returns (bool) {
    uint256 reward = config.getAlloyxStakeInfo().claimableCRWNToken(msg.sender);
    config.getCRWN().mint(msg.sender, reward);
    config.getAlloyxStakeInfo().resetStakeTimestampWithRewardLeft(msg.sender, 0);
    emit Claim(msg.sender, reward);
    return true;
  }

  /**
   * @notice Claim certain amount of alloy CRWN tokens of the message sender, the method will mint the CRWN token of
   * the claimable amount to message sender, and clear the past rewards to the remainder
   * @param _amount the amount to claim
   */
  function claimAlloyxCRWN(uint256 _amount) external returns (bool) {
    uint256 allReward = config.getAlloyxStakeInfo().claimableCRWNToken(msg.sender);
    require(allReward >= _amount, "User has claimed more than he's entitled");
    config.getCRWN().mint(msg.sender, _amount);
    config.getAlloyxStakeInfo().resetStakeTimestampWithRewardLeft(
      msg.sender,
      allReward.sub(_amount)
    );
    emit Claim(msg.sender, _amount);
    return true;
  }

  /**
   * @notice Claim certain amount of reward token based on alloy CRWN token, the method will burn the CRWN token of
   * the amount of message sender, and transfer reward token to message sender
   * @param _amount the amount to claim
   */
  function claimReward(uint256 _amount) external returns (bool) {
    (uint256 amountToReward, uint256 fee) = getRewardTokenCount(_amount);
    config.getTreasury().transferERC20(config.gfiAddress(), msg.sender, amountToReward.sub(fee));
    config.getTreasury().addEarningGfiFee(fee);
    config.getCRWN().burn(msg.sender, _amount);
    emit Reward(msg.sender, _amount);
    return true;
  }

  /**
   * @notice Get reward token count if the amount of CRWN tokens are claimed
   * @param _amount the amount to claim
   */
  function getRewardTokenCount(uint256 _amount) public view returns (uint256, uint256) {
    uint256 amountToReward = _amount
      .mul(
        config.getGFI().balanceOf(config.treasuryAddress()).sub(
          config.getTreasury().getEarningGfiFee()
        )
      )
      .div(totalClaimableAndClaimedCRWNToken());
    uint256 fee = amountToReward.mul(config.getPercentageCRWNEarning()).div(100);
    return (amountToReward, fee);
  }
}
