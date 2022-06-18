// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AlloyX Vault
 * @notice Initial vault for AlloyX. This vault holds loan tokens generated on Goldfinch
 * and emits AlloyTokens when a liquidity provider deposits supported stable coins.
 * @author AlloyX
 */
contract AlloyxStakeInfo is Ownable {
  using SafeMath for uint256;
  struct StakeInfo {
    uint256 amount;
    uint256 since;
  }
  uint256 public percentageRewardPerYear = 2;
  uint256 public totalPastRedeemableReward;
  mapping(address => uint256) private pastRedeemableReward;
  mapping(address => StakeInfo) private stakesMapping;
  mapping(address => bool) private stakeholderMap;
  StakeInfo totalActiveStake;
  address vaultAddress;
  event SetField(string _field, uint256 _value);

  constructor(address _vaultAddress) public {
    vaultAddress = _vaultAddress;
  }

  /**
   * @notice If it is called from the vault
   */
  modifier fromVault() {
    require(vaultAddress == msg.sender, "The function must be called from vault");
    _;
  }

  /**
   * @notice Change the vault address
   * @param _vaultAddress The address to change to
   */
  function changeVaultAddress(address _vaultAddress) external onlyOwner {
    vaultAddress = _vaultAddress;
  }

  /**
   * @notice Set percentageRewardPerYear which is the reward per year in percentage
   * @param _percentageRewardPerYear the reward per year in percentage
   */
  function setPercentageRewardPerYear(uint256 _percentageRewardPerYear) external onlyOwner {
    percentageRewardPerYear = _percentageRewardPerYear;
    emit SetField("percentageRewardPerYear", _percentageRewardPerYear);
  }

  /**
   * @notice Check if an address is a stakeholder.
   * @param _address The address to verify.
   * @return bool Whether the address is a stakeholder,
   * and if so its position in the stakeholders array.
   */
  function isStakeholder(address _address) public view returns (bool) {
    return stakeholderMap[_address];
  }

  /**
   * @notice Add a stakeholder.
   * @param _stakeholder The stakeholder to add.
   */
  function addStakeholder(address _stakeholder) internal {
    stakeholderMap[_stakeholder] = true;
  }

  /**
   * @notice Remove a stakeholder.
   * @param _stakeholder The stakeholder to remove.
   */
  function removeStakeholder(address _stakeholder) internal {
    stakeholderMap[_stakeholder] = false;
  }

  /**
   * @notice Retrieve the stake for a stakeholder.
   * @param _stakeholder The stakeholder to retrieve the stake for.
   * @return Stake The amount staked and the time since when it's staked.
   */
  function stakeOf(address _stakeholder) public view returns (StakeInfo memory) {
    return stakesMapping[_stakeholder];
  }

  /**
   * @notice A method for a stakeholder to reset the timestamp of the stake.
   * @notice A method for a stakeholder to reset the timestamp of the stake.
   * @param _stakeholder The stakeholder to retrieve the stake for.
   */
  function resetStakeTimestamp(address _stakeholder) internal {
    if (stakesMapping[_stakeholder].amount == 0) addStakeholder(_stakeholder);
    addPastRedeemableReward(_stakeholder, stakesMapping[_stakeholder]);
    stakesMapping[_stakeholder] = StakeInfo(stakesMapping[_stakeholder].amount, block.timestamp);
  }

  /**
   * @notice Add stake for a staker
   * @param _staker The person intending to stake
   * @param _stake The size of the stake to be created.
   */
  function addStake(address _staker, uint256 _stake) public fromVault {
    if (stakesMapping[_staker].amount == 0) addStakeholder(_staker);
    addPastRedeemableReward(_staker, stakesMapping[_staker]);
    stakesMapping[_staker] = StakeInfo(stakesMapping[_staker].amount.add(_stake), block.timestamp);
    updateTotalStakeInfoAndPastRedeemable(_stake, 0, 0, 0);
  }

  /**
   * @notice Remove stake for a staker
   * @param _staker The person intending to remove stake
   * @param _stake The size of the stake to be removed.
   */
  function removeStake(address _staker, uint256 _stake) public fromVault {
    require(stakeOf(_staker).amount >= _stake, "User has insufficient dura coin staked");
    if (stakesMapping[_staker].amount == 0) addStakeholder(_staker);
    addPastRedeemableReward(_staker, stakesMapping[_staker]);
    stakesMapping[_staker] = StakeInfo(stakesMapping[_staker].amount.sub(_stake), block.timestamp);
    updateTotalStakeInfoAndPastRedeemable(0, _stake, 0, 0);
  }

  /**
   * @notice Add the stake to past redeemable reward
   * @param _stake the stake to be added into the reward
   */
  function addPastRedeemableReward(address _staker, StakeInfo storage _stake) internal {
    uint256 additionalPastRedeemableReward = calculateRewardFromStake(_stake);
    pastRedeemableReward[_staker] = pastRedeemableReward[_staker].add(
      additionalPastRedeemableReward
    );
  }

  function updateTotalStakeInfoAndPastRedeemable(
    uint256 increaseInStake,
    uint256 decreaseInStake,
    uint256 increaseInPastRedeemable,
    uint256 decreaseInPastRedeemable
  ) internal {
    uint256 additionalPastRedeemableReward = calculateRewardFromStake(totalActiveStake);
    totalPastRedeemableReward = totalPastRedeemableReward.add(additionalPastRedeemableReward);
    totalPastRedeemableReward = totalPastRedeemableReward.add(increaseInPastRedeemable).sub(
      decreaseInPastRedeemable
    );
    totalActiveStake = StakeInfo(
      totalActiveStake.amount.add(increaseInStake).sub(decreaseInStake),
      block.timestamp
    );
  }

  /**
   * @notice A method for a stakeholder to clear a stake with some leftover reward
   * @param _staker the address of the staker
   * @param _reward the leftover reward the staker owns
   */
  function resetStakeTimestampWithRewardLeft(address _staker, uint256 _reward) public fromVault {
    resetStakeTimestamp(_staker);
    adjustTotalStakeWithRewardLeft(_staker, _reward);
    pastRedeemableReward[_staker] = _reward;
  }

  /**
   * @notice Adjust total stake variables with leftover reward
   * @param _reward the leftover reward the staker owns
   */
  function adjustTotalStakeWithRewardLeft(address _staker, uint256 _reward) internal {
    uint256 increaseInPastReward = 0;
    uint256 decreaseInPastReward = 0;
    if (pastRedeemableReward[_staker] >= _reward) {
      decreaseInPastReward = pastRedeemableReward[_staker].sub(_reward);
    } else {
      increaseInPastReward = _reward.sub(pastRedeemableReward[_staker]);
    }
    updateTotalStakeInfoAndPastRedeemable(0, 0, increaseInPastReward, decreaseInPastReward);
  }

  /**
   * @notice Calculate reward from the stake info
   * @param _stake the stake info to calculate reward based on
   */
  function calculateRewardFromStake(StakeInfo memory _stake) internal view returns (uint256) {
    return
      _stake
        .amount
        .mul(block.timestamp.sub(_stake.since))
        .mul(percentageRewardPerYear)
        .div(100)
        .div(365 days);
  }

  /**
   * @notice Claimable CRWN token amount of an address
   * @param _receiver the address of receiver
   */
  function claimableCRWNToken(address _receiver) public view returns (uint256) {
    StakeInfo memory stakeValue = stakeOf(_receiver);
    return pastRedeemableReward[_receiver] + calculateRewardFromStake(stakeValue);
  }

  /**
   * @notice Total claimable CRWN tokens of all stakeholders
   */
  function totalClaimableCRWNToken() public view returns (uint256) {
    return calculateRewardFromStake(totalActiveStake) + totalPastRedeemableReward;
  }
}
