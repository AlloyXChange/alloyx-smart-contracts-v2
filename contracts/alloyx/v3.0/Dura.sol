// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Crown.sol";

contract Dura is ERC20, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for Crown;
  struct StakeInfo {
    uint256 amount;
    uint256 since;
  }
  Crown private crown;
  uint256 public constant REWARD_MULTIPLIER = 1;
  uint256 public constant PERIOD_PER_REWARD_CYCLE = 365 days;
  address[] internal stakeholders;
  mapping(address => StakeInfo) stakesMapping;
  mapping(address => uint256) pastRedeemableReward;
  mapping(address => uint256) rewardCap;
  event Reward(address _tokenReceiver, uint256 _tokenAmount);
  event Stake(address _staker, uint256 _amount);

  constructor(address _crownAddress) ERC20("Duralumin", "DURA") {
    crown = Crown(_crownAddress);
  }

  function changeCrownAddress(address _alloyxSilverAddress) external onlyOwner {
    crown = Crown(_alloyxSilverAddress);
  }

  function mint(address account, uint256 amount) external onlyOwner returns (bool) {
    _mint(account, amount);
    uint256 rewardCapToAdd = amount.mul(REWARD_MULTIPLIER);
    rewardCap[account] = rewardCap[account].add(rewardCapToAdd);
    crown.mint(address(this), rewardCapToAdd);
    return true;
  }

  function mintAndStake(
    address account,
    address stakeholder,
    uint256 amount
  ) external onlyOwner returns (bool) {
    _mint(stakeholder, amount);
    uint256 rewardCapToAdd = amount.mul(REWARD_MULTIPLIER);
    setRewardToExistingCapIfReached(account);
    rewardCap[account] = rewardCap[account].add(rewardCapToAdd);
    crown.mint(address(this), rewardCapToAdd);
    addStake(account, amount);
    return true;
  }

  function burn(address account, uint256 amount) external onlyOwner returns (bool) {
    _burn(account, amount);
    uint256 rewardCapToReduce = amount.mul(REWARD_MULTIPLIER);
    if (rewardCap[account].sub(redeemableCrown(account)) > rewardCapToReduce) {
      rewardCap[account] = rewardCap[account].sub(rewardCapToReduce);
      crown.burn(address(this), rewardCapToReduce);
    } else {
      rewardCap[account] = redeemableCrown(account);
      crown.burn(address(this), rewardCap[account].sub(redeemableCrown(account)));
    }
    return true;
  }

  function transfer(address to, uint256 amount) public override returns (bool) {
    address owner = _msgSender();
    _transfer(owner, to, amount);
    uint256 rewardCapToChange = amount.mul(REWARD_MULTIPLIER);
    if (rewardCap[owner].sub(redeemableCrown(owner)) > rewardCapToChange) {
      rewardCap[owner] = rewardCap[owner].sub(rewardCapToChange);
      setRewardToExistingCapIfReached(to);
      rewardCap[to] = rewardCap[to].add(rewardCapToChange);
    } else {
      rewardCap[owner] = redeemableCrown(owner);
      setRewardToExistingCapIfReached(to);
      rewardCap[to] = rewardCap[to].add(rewardCap[owner].sub(redeemableCrown(owner)));
    }
    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public override returns (bool) {
    address spender = _msgSender();
    _spendAllowance(from, spender, amount);
    _transfer(from, to, amount);
    uint256 rewardCapToChange = amount.mul(REWARD_MULTIPLIER);
    if (rewardCap[from].sub(redeemableCrown(from)) > rewardCapToChange) {
      rewardCap[from] = rewardCap[from].sub(rewardCapToChange);
      rewardCap[to] = rewardCap[to].add(rewardCapToChange);
    } else {
      rewardCap[from] = redeemableCrown(from);
      rewardCap[to] = rewardCap[to].add(rewardCap[from].sub(redeemableCrown(from)));
    }
    return true;
  }

  /**
   * @notice A method to check if an address is a stakeholder.
   * @param _address The address to verify.
   * @return bool, uint256 Whether the address is a stakeholder,
   * and if so its position in the stakeholders array.
   */
  function isStakeholder(address _address) public view returns (bool, uint256) {
    for (uint256 s = 0; s < stakeholders.length; s += 1) {
      if (_address == stakeholders[s]) return (true, s);
    }
    return (false, 0);
  }

  /**
   * @notice A method to add a stakeholder.
   * @param _stakeholder The stakeholder to add.
   */
  function addStakeholder(address _stakeholder) internal {
    (bool _isStakeholder, ) = isStakeholder(_stakeholder);
    if (!_isStakeholder) stakeholders.push(_stakeholder);
  }

  /**
   * @notice A method to remove a stakeholder.
   * @param _stakeholder The stakeholder to remove.
   */
  function removeStakeholder(address _stakeholder) internal {
    (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
    if (_isStakeholder) {
      stakeholders[s] = stakeholders[stakeholders.length.sub(1)];
      stakeholders.pop();
    }
  }

  /**
   * @notice A method to retrieve the stake for a stakeholder.
   * @param _stakeholder The stakeholder to retrieve the stake for.
   * @return Stake The amount staked and the time since when it's staked.
   */
  function stakeOf(address _stakeholder) public view returns (StakeInfo memory) {
    return stakesMapping[_stakeholder];
  }

  /**
   * @notice A method for a stakeholder to create a stake.
   * @param _stake The size of the stake to be created.
   */
  function createStake(address _staker, uint256 _stake) internal {
    if (stakesMapping[_staker].amount == 0) addStakeholder(_staker);
    addPastRedeemableReward(_staker, stakesMapping[_staker]);
    stakesMapping[_staker] = StakeInfo(_stake, block.timestamp);
    emit Stake(_staker, _stake);
  }

  /**
   * @notice A method for a stakeholder to clear a stake.
   */
  function clearStake(address _staker) internal {
    createStake(_staker, 0);
  }

  /**
   * @notice A method for a stakeholder to clear a stake with reward
   * @param _reward the leftover reward the staker owns
   */
  function clearStakeWithRewardLeft(address _staker, uint256 _reward) internal {
    createStake(_staker, 0);
    pastRedeemableReward[_staker] = _reward;
  }

  /**
   * @notice A method for a stakeholder to reset a stake with reward and stake amount
   * @param _reward the leftover reward the staker owns
   */
  function resetStakeWithStakeAmountAndRewardLeft(
    address _staker,
    uint256 _amount,
    uint256 _reward
  ) internal {
    createStake(_staker, _amount);
    pastRedeemableReward[_staker] = _reward;
  }

  function addStake(address _staker, uint256 _stake) public {
    if (stakesMapping[_staker].amount == 0) addStakeholder(_staker);
    addPastRedeemableReward(_staker, stakesMapping[_staker]);
    stakesMapping[_staker] = StakeInfo(stakesMapping[_staker].amount.add(_stake), block.timestamp);
  }

  function removeStake(address _staker, uint256 _stake) public {
    require(stakeOf(msg.sender).amount >= _stake, "User has insufficient dura coin staked");
    if (stakesMapping[_staker].amount == 0) addStakeholder(_staker);
    addPastRedeemableReward(_staker, stakesMapping[_staker]);
    stakesMapping[_staker] = StakeInfo(stakesMapping[_staker].amount.sub(_stake), block.timestamp);
  }

  /**
   * @notice add the stake to past redeemable reward
   * @param _stake the stake to be added into the reward
   */
  function addPastRedeemableReward(address _staker, StakeInfo storage _stake) internal {
    uint256 additionalPastRedeemableReward = calculateRewardFromStake(_stake);
    pastRedeemableReward[_staker] = pastRedeemableReward[_staker].add(
      additionalPastRedeemableReward
    );
  }

  function calculateRewardFromStake(StakeInfo memory _stake) internal view returns (uint256) {
    return
      _stake.amount.mul(REWARD_MULTIPLIER).mul(block.timestamp.sub(_stake.since)).div(
        PERIOD_PER_REWARD_CYCLE
      );
  }

  function redeemableCrown(address receiverAddress) public view returns (uint256) {
    StakeInfo memory stake = stakeOf(receiverAddress);
    uint256 redeemableBeforeCapping = pastRedeemableReward[receiverAddress].add(calculateRewardFromStake(stake));
    uint256 capOfRedeemable = rewardCap[receiverAddress];
    if (capOfRedeemable >= redeemableBeforeCapping) {
      return redeemableBeforeCapping;
    }
    return capOfRedeemable;
  }

  function setRewardToExistingCapIfReached(address account) internal {
    uint256 cap = rewardCap[account];
    StakeInfo memory stake = stakeOf(account);
    uint256 redeemableBeforeCapping = pastRedeemableReward[account].add(calculateRewardFromStake(stake));
    if (redeemableBeforeCapping > cap) {
      resetStakeWithStakeAmountAndRewardLeft(account, stake.amount, cap);
    }
  }

  function redeemAllCrown(address redeemer) external returns (bool) {
    uint256 reward = redeemableCrown(redeemer);
    crown.safeTransfer(redeemer, reward);
    clearStakeWithRewardLeft(redeemer, 0);
    rewardCap[redeemer] = rewardCap[redeemer].sub(reward);
    emit Reward(redeemer, reward);
    return true;
  }

  function redeemCrown(address redeemer, uint256 _amount) external returns (bool) {
    uint256 allReward = redeemableCrown(redeemer);
    require(allReward >= _amount, "User has redeemed more than he's entitled");
    crown.safeTransfer(redeemer, _amount);
    clearStakeWithRewardLeft(redeemer, allReward.sub(_amount));
    rewardCap[redeemer] = rewardCap[redeemer].sub(_amount);
    emit Reward(redeemer, _amount);
    return true;
  }
}
