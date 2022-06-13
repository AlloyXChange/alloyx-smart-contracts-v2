// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./AlloyxTokenDURA.sol";
import "./AlloyxTokenCRWN.sol";
import "./IGoldfinchDelegacy.sol";

/**
 * @title AlloyX Vault
 * @notice Initial vault for AlloyX. This vault holds loan tokens generated on Goldfinch
 * and emits AlloyTokens when a liquidity provider deposits supported stable coins.
 * @author AlloyX
 */
contract AlloyxVault is ERC721Holder, Ownable, Pausable {
  using SafeERC20 for IERC20;
  using SafeERC20 for AlloyxTokenDURA;
  using SafeMath for uint256;
  struct StakeInfo {
    uint256 amount;
    uint256 since;
  }
  bool private vaultStarted;
  IERC1155 private uidToken;
  IERC20 private usdcCoin;
  AlloyxTokenDURA private alloyxTokenDURA;
  AlloyxTokenCRWN private alloyxTokenCRWN;
  IGoldfinchDelegacy private goldfinchDelegacy;
  mapping(address => bool) private stakeholderMap;
  mapping(address => StakeInfo) private stakesMapping;
  mapping(address => uint256) private pastRedeemableReward;
  mapping(address => bool) whitelistedAddresses;
  uint256 public percentageRewardPerYear = 2;
  uint256 public percentageDURARedemption = 1;
  uint256 public percentageDuraToFiduFee = 1;
  uint256 public percentageDURARepayment = 2;
  uint256 public percentageCRWNEarning = 10;
  uint256 public percentageInvestJunior = 60;
  uint256 public redemptionFee = 0;
  uint256 public duraToFiduFee = 0;
  StakeInfo totalActiveStake;
  uint256 totalPastRedeemableReward;
  uint256 public constant ID_VERSION_0 = 0;

  event DepositStable(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event DepositNftForDura(address _tokenAddress, address _tokenSender, uint256 _tokenID);
  event DepositNftForUsdc(address _tokenAddress, address _tokenSender, uint256 _tokenID);
  event DepositAlloyx(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event PurchaseSenior(uint256 amount);
  event SellSenior(uint256 amount);
  event PurchaseJunior(uint256 amount);
  event SellJunior(uint256 amount);
  event Mint(address _tokenReceiver, uint256 _tokenAmount);
  event Burn(address _tokenReceiver, uint256 _tokenAmount);
  event Reward(address _tokenReceiver, uint256 _tokenAmount);
  event Claim(address _tokenReceiver, uint256 _tokenAmount);
  event Stake(address _staker, uint256 _amount);
  event Unstake(address _unstaker, uint256 _amount);
  event SetField(string _field, uint256 _value);
  event ChangeAddress(string _field, address _address);

  constructor(
    address _alloyxDURAAddress,
    address _alloyxCRWNAddress,
    address _usdcCoinAddress,
    address _goldfinchDelegacy,
    address _uidAddress
  ) {
    alloyxTokenDURA = AlloyxTokenDURA(_alloyxDURAAddress);
    alloyxTokenCRWN = AlloyxTokenCRWN(_alloyxCRWNAddress);
    usdcCoin = IERC20(_usdcCoinAddress);
    goldfinchDelegacy = IGoldfinchDelegacy(_goldfinchDelegacy);
    uidToken = IERC1155(_uidAddress);
    vaultStarted = false;
  }

  /**
   * @notice If vault is started
   */
  modifier whenVaultStarted() {
    require(vaultStarted, "Vault has not start accepting deposits");
    _;
  }

  /**
   * @notice If vault is not started
   */
  modifier whenVaultNotStarted() {
    require(!vaultStarted, "Vault has already start accepting deposits");
    _;
  }

  /**
   * @notice If address is whitelisted
   * @param _address The address to verify.
   */
  modifier isWhitelisted(address _address) {
    require(
      whitelistedAddresses[_address] || hasWhitelistedUID(_address),
      "You need to be whitelisted"
    );
    _;
  }

  /**
   * @notice If address is not whitelisted
   * @param _address The address to verify.
   */
  modifier notWhitelisted(address _address) {
    require(!whitelistedAddresses[_address] && !hasWhitelistedUID(_address), "You are whitelisted");
    _;
  }

  /**
   * @notice If address is not whitelisted by goldfinch(non-US entity or non-US individual)
   * @param _userAddress The address to verify.
   */
  function hasWhitelistedUID(address _userAddress) public view returns (bool) {
    uint256 balanceForNonUsIndividual = uidToken.balanceOf(_userAddress, 0);
    uint256 balanceForNonUsEntity = uidToken.balanceOf(_userAddress, 4);
    return balanceForNonUsIndividual + balanceForNonUsEntity > 0;
  }

  /**
   * @notice Initialize by minting the alloy brown tokens to owner
   */
  function startVaultOperation() external onlyOwner whenVaultNotStarted returns (bool) {
    uint256 totalBalanceInUSDC = getAlloyxDURATokenBalanceInUSDC();
    require(totalBalanceInUSDC > 0, "Vault must have positive value before start");
    alloyxTokenDURA.mint(
      address(this),
      totalBalanceInUSDC.mul(alloyMantissa()).div(usdcMantissa())
    );
    vaultStarted = true;
    return true;
  }

  /**
   * @notice Pause all operations except migration of tokens
   */
  function pause() external onlyOwner whenNotPaused {
    _pause();
  }

  /**
   * @notice Unpause all operations
   */
  function unpause() external onlyOwner whenPaused {
    _unpause();
  }

  /**
   * @notice Add whitelist address
   * @param _addressToWhitelist The address to whitelist.
   */
  function addWhitelistedUser(address _addressToWhitelist)
    public
    onlyOwner
    notWhitelisted(_addressToWhitelist)
  {
    whitelistedAddresses[_addressToWhitelist] = true;
  }

  /**
   * @notice Remove whitelist address
   * @param _addressToDeWhitelist The address to de-whitelist.
   */
  function removeWhitelistedUser(address _addressToDeWhitelist)
    public
    onlyOwner
    isWhitelisted(_addressToDeWhitelist)
  {
    whitelistedAddresses[_addressToDeWhitelist] = false;
  }

  /**
   * @notice Check whether user is whitelisted
   * @param _whitelistedAddress The address to whitelist.
   */
  function isUserWhitelisted(address _whitelistedAddress) public view returns (bool) {
    return whitelistedAddresses[_whitelistedAddress] || hasWhitelistedUID(_whitelistedAddress);
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
   */
  function resetStakeTimestamp() internal {
    if (stakesMapping[msg.sender].amount == 0) addStakeholder(msg.sender);
    addPastRedeemableReward(msg.sender, stakesMapping[msg.sender]);
    stakesMapping[msg.sender] = StakeInfo(stakesMapping[msg.sender].amount, block.timestamp);
  }

  /**
   * @notice Add stake for a staker
   * @param _staker The person intending to stake
   * @param _stake The size of the stake to be created.
   */
  function addStake(address _staker, uint256 _stake) internal {
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
  function removeStake(address _staker, uint256 _stake) internal {
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

  /**
   * @notice Stake more into the vault, which will cause the user's DURA token to transfer to vault
   * @param _amount the amount the message sender intending to stake in
   */
  function stake(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    addStake(msg.sender, _amount);
    alloyxTokenDURA.safeTransferFrom(msg.sender, address(this), _amount);
    emit Stake(msg.sender, _amount);
    return true;
  }

  /**
   * @notice Unstake some from the vault, which will cause the vault to transfer DURA token back to message sender
   * @param _amount the amount the message sender intending to unstake
   */
  function unstake(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    removeStake(msg.sender, _amount);
    alloyxTokenDURA.safeTransfer(msg.sender, _amount);
    emit Unstake(msg.sender, _amount);
    return true;
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
   * @param _reward the leftover reward the staker owns
   */
  function resetStakeTimestampWithRewardLeft(uint256 _reward) internal {
    resetStakeTimestamp();
    adjustTotalStakeWithRewardLeft(_reward);
    pastRedeemableReward[msg.sender] = _reward;
  }

  /**
   * @notice Adjust total stake variables with leftover reward
   * @param _reward the leftover reward the staker owns
   */
  function adjustTotalStakeWithRewardLeft(uint256 _reward) internal {
    uint256 increaseInPastReward = 0;
    uint256 decreaseInPastReward = 0;
    if (pastRedeemableReward[msg.sender] >= _reward) {
      decreaseInPastReward = pastRedeemableReward[msg.sender].sub(_reward);
    } else {
      increaseInPastReward = _reward.sub(pastRedeemableReward[msg.sender]);
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

  /**
   * @notice Total claimable and claimed CRWN tokens of all stakeholders
   */
  function totalClaimableAndClaimedCRWNToken() public view returns (uint256) {
    return totalClaimableCRWNToken().add(alloyxTokenCRWN.totalSupply());
  }

  /**
   * @notice Claim all alloy CRWN tokens of the message sender, the method will mint the CRWN token of the claimable
   * amount to message sender, and clear the past rewards to zero
   */
  function claimAllAlloyxCRWN() external whenNotPaused whenVaultStarted returns (bool) {
    uint256 reward = claimableCRWNToken(msg.sender);
    alloyxTokenCRWN.mint(msg.sender, reward);
    resetStakeTimestampWithRewardLeft(0);
    emit Claim(msg.sender, reward);
    return true;
  }

  /**
   * @notice Claim certain amount of alloy CRWN tokens of the message sender, the method will mint the CRWN token of
   * the claimable amount to message sender, and clear the past rewards to the remainder
   * @param _amount the amount to claim
   */
  function claimAlloyxCRWN(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    uint256 allReward = claimableCRWNToken(msg.sender);
    require(allReward >= _amount, "User has claimed more than he's entitled");
    alloyxTokenCRWN.mint(msg.sender, _amount);
    resetStakeTimestampWithRewardLeft(allReward.sub(_amount));
    emit Claim(msg.sender, _amount);
    return true;
  }

  /**
   * @notice Claim certain amount of reward token based on alloy CRWN token, the method will burn the CRWN token of
   * the amount of message sender, and transfer reward token to message sender
   * @param _amount the amount to claim
   */
  function claimReward(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    require(
      alloyxTokenCRWN.balanceOf(address(msg.sender)) >= _amount,
      "Balance of crown coin must be larger than the amount to claim"
    );
    goldfinchDelegacy.claimReward(
      msg.sender,
      _amount,
      totalClaimableAndClaimedCRWNToken(),
      percentageCRWNEarning
    );
    alloyxTokenCRWN.burn(msg.sender, _amount);
    emit Reward(msg.sender, _amount);
    return true;
  }

  /**
   * @notice Get reward token count if the amount of CRWN tokens are claimed
   * @param _amount the amount to claim
   */
  function getRewardTokenCount(uint256 _amount) external view returns (uint256) {
    return
      goldfinchDelegacy.getRewardAmount(
        _amount,
        totalClaimableAndClaimedCRWNToken(),
        percentageCRWNEarning
      );
  }

  /**
   * @notice Request the delegacy to approve certain tokens on certain account for certain amount, it is most used for
   * buying the goldfinch tokens, they need to be able to transfer usdc to them
   * @param _tokenAddress the leftover reward the staker owns
   * @param _account the account the delegacy going to approve
   * @param _amount the amount the delegacy going to approve
   */
  function approveDelegacy(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external onlyOwner {
    goldfinchDelegacy.approve(_tokenAddress, _account, _amount);
  }

  /**
   * @notice Alloy DURA Token Value in terms of USDC
   */
  function getAlloyxDURATokenBalanceInUSDC() public view returns (uint256) {
    uint256 totalValue = getUSDCBalance().add(
      goldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()
    );
    uint256 entireFee = redemptionFee.add(duraToFiduFee);
    require(
      totalValue > entireFee,
      "the value of vault is not larger than the fee, something went wrong"
    );
    return
      getUSDCBalance().add(goldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()).sub(entireFee);
  }

  /**
   * @notice USDC Value in Vault
   */
  function getUSDCBalance() internal view returns (uint256) {
    return usdcCoin.balanceOf(address(this));
  }

  /**
   * @notice Convert Alloyx DURA to USDC amount
   * @param _amount the amount of DURA token to convert to usdc
   */
  function alloyxDURAToUSDC(uint256 _amount) public view returns (uint256) {
    uint256 alloyDURATotalSupply = alloyxTokenDURA.totalSupply();
    uint256 totalVaultAlloyxDURAValueInUSDC = getAlloyxDURATokenBalanceInUSDC();
    return _amount.mul(totalVaultAlloyxDURAValueInUSDC).div(alloyDURATotalSupply);
  }

  /**
   * @notice Convert USDC Amount to Alloyx DURA
   * @param _amount the amount of usdc to convert to DURA token
   */
  function usdcToAlloyxDURA(uint256 _amount) public view returns (uint256) {
    uint256 alloyDURATotalSupply = alloyxTokenDURA.totalSupply();
    uint256 totalVaultAlloyxDURAValueInUSDC = getAlloyxDURATokenBalanceInUSDC();
    return _amount.mul(alloyDURATotalSupply).div(totalVaultAlloyxDURAValueInUSDC);
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
   * @notice Set percentageDURARedemption which is the redemption fee for DURA token in percentage
   * @param _percentageDURARedemption the redemption fee for DURA token in percentage
   */
  function setPercentageDURARedemption(uint256 _percentageDURARedemption) external onlyOwner {
    percentageDURARedemption = _percentageDURARedemption;
    emit SetField("percentageDURARedemption", _percentageDURARedemption);
  }

  /**
   * @notice Set percentageDURARepayment which is the repayment fee for DURA token in percentage
   * @param _percentageDURARepayment the repayment fee for DURA token in percentage
   */
  function setPercentageDURARepayment(uint256 _percentageDURARepayment) external onlyOwner {
    percentageDURARepayment = _percentageDURARepayment;
    emit SetField("percentageDURARepayment", _percentageDURARepayment);
  }

  /**
   * @notice Set percentageDuraToFiduFee which is the fee for DURA token to exchange to FIDU in percentage
   * @param _percentageDuraToFiduFee the fee for DURA token to exchange to FIDU in percentage
   */
  function setPercentageDuraToFiduFee(uint256 _percentageDuraToFiduFee) external onlyOwner {
    percentageDuraToFiduFee = _percentageDuraToFiduFee;
    emit SetField("percentageDuraToFiduFee", _percentageDuraToFiduFee);
  }

  /**
   * @notice Set percentageCRWNEarning which is the earning fee for redeeming CRWN token in percentage in terms of gfi
   * @param _percentageCRWNEarning the earning fee for redeeming CRWN token in percentage in terms of gfi
   */
  function setPercentageCRWNEarning(uint256 _percentageCRWNEarning) external onlyOwner {
    percentageCRWNEarning = _percentageCRWNEarning;
    emit SetField("percentageCRWNEarning", _percentageCRWNEarning);
  }

  /**
   * @notice Alloy token with 18 decimals
   */
  function alloyMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(18);
  }

  /**
   * @notice USDC mantissa with 6 decimals
   */
  function usdcMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(6);
  }

  /**
   * @notice Change DURA token address
   * @param _alloyxAddress the address to change to
   */
  function changeAlloyxDURAAddress(address _alloyxAddress) external onlyOwner {
    alloyxTokenDURA = AlloyxTokenDURA(_alloyxAddress);
    emit ChangeAddress("alloyxTokenDURA", _alloyxAddress);
  }

  /**
   * @notice Change CRWN token address
   * @param _alloyxAddress the address to change to
   */
  function changeAlloyxCRWNAddress(address _alloyxAddress) external onlyOwner {
    alloyxTokenCRWN = AlloyxTokenCRWN(_alloyxAddress);
    emit ChangeAddress("alloyxTokenCRWN", _alloyxAddress);
  }

  /**
   * @notice Change Goldfinch delegacy address
   * @param _goldfinchDelegacy the address to change to
   */
  function changeGoldfinchDelegacyAddress(address _goldfinchDelegacy) external onlyOwner {
    goldfinchDelegacy = IGoldfinchDelegacy(_goldfinchDelegacy);
    emit ChangeAddress("goldfinchDelegacy", _goldfinchDelegacy);
  }

  /**
   * @notice Change USDC address
   * @param _usdcAddress the address to change to
   */
  function changeUSDCAddress(address _usdcAddress) external onlyOwner {
    usdcCoin = IERC20(_usdcAddress);
    emit ChangeAddress("usdcCoin", _usdcAddress);
  }

  /**
   * @notice Change UID address
   * @param _uidAddress the address to change to
   */
  function changeUIDAddress(address _uidAddress) external onlyOwner {
    uidToken = IERC1155(_uidAddress);
    emit ChangeAddress("uidToken", _uidAddress);
  }

  /**
   * @notice An Alloy token holder can deposit their tokens and redeem them for USDC
   * @param _tokenAmount Number of Alloy Tokens
   */
  function depositAlloyxDURATokens(uint256 _tokenAmount)
    external
    whenNotPaused
    whenVaultStarted
    isWhitelisted(msg.sender)
    returns (bool)
  {
    require(
      alloyxTokenDURA.balanceOf(msg.sender) >= _tokenAmount,
      "User has insufficient alloyx coin."
    );
    require(
      alloyxTokenDURA.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient alloyx coin"
    );
    uint256 amountToWithdraw = alloyxDURAToUSDC(_tokenAmount);
    uint256 withdrawalFee = amountToWithdraw.mul(percentageDURARedemption).div(100);
    require(amountToWithdraw > 0, "The amount of stable coin to get is not larger than 0");
    require(
      usdcCoin.balanceOf(address(this)) >= amountToWithdraw,
      "The vault does not have sufficient stable coin"
    );
    alloyxTokenDURA.burn(msg.sender, _tokenAmount);
    usdcCoin.safeTransfer(msg.sender, amountToWithdraw.sub(withdrawalFee));
    redemptionFee = redemptionFee.add(withdrawalFee);
    emit DepositAlloyx(address(alloyxTokenDURA), msg.sender, _tokenAmount);
    emit Burn(msg.sender, _tokenAmount);
    return true;
  }

  /**
   * @notice An Alloy token holder can deposit their tokens and buy FIDU
   * @param _tokenAmount Number of Alloy Tokens
   */
  function depositAlloyxDURATokensForFIDU(uint256 _tokenAmount)
    external
    whenNotPaused
    whenVaultStarted
    isWhitelisted(msg.sender)
    returns (bool)
  {
    require(
      alloyxTokenDURA.balanceOf(msg.sender) >= _tokenAmount,
      "User has insufficient alloyx coin."
    );
    require(
      alloyxTokenDURA.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient alloyx coin"
    );
    uint256 amountToWithdraw = alloyxDURAToUSDC(_tokenAmount);
    uint256 withdrawalFee = amountToWithdraw.mul(percentageDuraToFiduFee).div(100);
    uint256 totalUsdcValueOfFidu = amountToWithdraw.sub(withdrawalFee);
    require(totalUsdcValueOfFidu > 0, "The amount of usdc value of FIDU is not larger than 0");
    alloyxTokenDURA.burn(msg.sender, _tokenAmount);
    usdcCoin.safeTransfer(address(goldfinchDelegacy), totalUsdcValueOfFidu);
    duraToFiduFee = duraToFiduFee.add(withdrawalFee);
    goldfinchDelegacy.purchaseSeniorTokensAndTransferTo(totalUsdcValueOfFidu, msg.sender);
    emit PurchaseSenior(totalUsdcValueOfFidu);
    emit DepositAlloyx(address(alloyxTokenDURA), msg.sender, _tokenAmount);
    emit Burn(msg.sender, _tokenAmount);
    return true;
  }

  /**
   * @notice A Liquidity Provider can deposit supported stable coins for Alloy Tokens
   * @param _tokenAmount Number of stable coin
   */
  function depositUSDCCoin(uint256 _tokenAmount)
    external
    whenNotPaused
    whenVaultStarted
    isWhitelisted(msg.sender)
    returns (bool)
  {
    require(usdcCoin.balanceOf(msg.sender) >= _tokenAmount, "User has insufficient stable coin");
    require(
      usdcCoin.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient stable coin"
    );
    uint256 amountToMint = usdcToAlloyxDURA(_tokenAmount);
    require(amountToMint > 0, "The amount of alloyx DURA coin to get is not larger than 0");
    usdcCoin.safeTransferFrom(msg.sender, address(goldfinchDelegacy), _tokenAmount);
    alloyxTokenDURA.mint(msg.sender, amountToMint);
    emit DepositStable(address(usdcCoin), msg.sender, amountToMint);
    emit Mint(msg.sender, amountToMint);
    return true;
  }

  /**
   * @notice A Liquidity Provider can deposit supported stable coins for Alloy Tokens
   * @param _tokenAmount Number of stable coin
   */
  function depositUSDCCoinWithStake(uint256 _tokenAmount)
    external
    whenNotPaused
    whenVaultStarted
    isWhitelisted(msg.sender)
    returns (bool)
  {
    require(usdcCoin.balanceOf(msg.sender) >= _tokenAmount, "User has insufficient stable coin");
    require(
      usdcCoin.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient stable coin"
    );
    uint256 amountToMint = usdcToAlloyxDURA(_tokenAmount);
    require(amountToMint > 0, "The amount of alloyx DURA coin to get is not larger than 0");
    usdcCoin.safeTransferFrom(msg.sender, address(this), _tokenAmount);
    alloyxTokenDURA.mint(address(this), amountToMint);
    addStake(msg.sender, amountToMint);
    emit DepositStable(address(usdcCoin), msg.sender, amountToMint);
    emit Mint(address(this), amountToMint);
    emit Stake(msg.sender, amountToMint);
    return true;
  }

  /**
   * @notice A Junior token holder can deposit their NFT for dura
   * @param _tokenAddress NFT Address
   * @param _tokenID NFT ID
   */
  function depositNFTTokenForDura(address _tokenAddress, uint256 _tokenID)
    external
    whenNotPaused
    whenVaultStarted
    isWhitelisted(msg.sender)
    returns (bool)
  {
    uint256 purchasePrice = goldfinchDelegacy.validatesTokenToDepositAndGetPurchasePrice(
      _tokenAddress,
      msg.sender,
      _tokenID
    );
    uint256 amountToMint = usdcToAlloyxDURA(purchasePrice);
    require(amountToMint > 0, "The amount of alloyx DURA coin to get is not larger than 0");
    IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(goldfinchDelegacy), _tokenID);
    alloyxTokenDURA.mint(msg.sender, amountToMint);
    emit Mint(msg.sender, amountToMint);
    emit DepositNftForDura(_tokenAddress, msg.sender, _tokenID);
    return true;
  }

  /**
   * @notice A Junior token holder can deposit their NFT for dura with stake
   * @param _tokenAddress NFT Address
   * @param _tokenID NFT ID
   */
  function depositNFTTokenForDuraWithStake(address _tokenAddress, uint256 _tokenID)
    external
    whenNotPaused
    whenVaultStarted
    isWhitelisted(msg.sender)
    returns (bool)
  {
    uint256 purchasePrice = goldfinchDelegacy.validatesTokenToDepositAndGetPurchasePrice(
      _tokenAddress,
      msg.sender,
      _tokenID
    );
    uint256 amountToMint = usdcToAlloyxDURA(purchasePrice);
    require(amountToMint > 0, "The amount of alloyx DURA coin to get is not larger than 0");
    IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(goldfinchDelegacy), _tokenID);
    alloyxTokenDURA.mint(address(this), amountToMint);
    addStake(msg.sender, amountToMint);
    emit Mint(address(this), amountToMint);
    emit DepositNftForDura(_tokenAddress, msg.sender, _tokenID);
    emit Stake(msg.sender, amountToMint);
    return true;
  }

  /**
   * @notice A Junior token holder can deposit their NFT for stable coin
   * @param _tokenAddress NFT Address
   * @param _tokenID NFT ID
   */
  function depositNFTTokenForUsdc(address _tokenAddress, uint256 _tokenID)
    external
    whenNotPaused
    whenVaultStarted
    isWhitelisted(msg.sender)
    returns (bool)
  {
    uint256 purchasePrice = goldfinchDelegacy.validatesTokenToDepositAndGetPurchasePrice(
      _tokenAddress,
      msg.sender,
      _tokenID
    );
    IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(goldfinchDelegacy), _tokenID);
    require(
      usdcCoin.balanceOf(address(this)) >= purchasePrice,
      "The vault does not have sufficient stable coin"
    );
    goldfinchDelegacy.payUsdc(msg.sender, purchasePrice);
    emit DepositNftForUsdc(_tokenAddress, msg.sender, _tokenID);
    return true;
  }

  /**
   * @notice Purchase junior token through delegacy to get pooltoken inside the delegacy
   */
  function purchaseJuniorTokenBeyondUsdcThreshold() public {
    uint256 totalValue = getAlloyxDURATokenBalanceInUSDC();
    uint256 entireVaultFee = redemptionFee.add(duraToFiduFee);
    uint256 usdcAvailableToInvest = getUSDCBalance()
      .add(goldfinchDelegacy.getUSDCBalanceAvailableForInvestment())
      .sub(entireVaultFee);
    require(
      usdcAvailableToInvest.mul(100).div(totalValue) > percentageInvestJunior,
      "usdc token must reach certain percentage"
    );
    usdcCoin.safeTransfer(address(goldfinchDelegacy), getUSDCBalance().sub(entireVaultFee));
    goldfinchDelegacy.purchaseJuniorTokenOnBestTranch(usdcAvailableToInvest);
    emit PurchaseJunior(usdcAvailableToInvest);
  }

  /**
   * @notice Purchase junior token through delegacy to get pooltoken inside the delegacy
   * @param _amount the amount of usdc to purchase by
   * @param _poolAddress the pool address to buy from
   * @param _tranche the tranch id
   */
  function purchaseJuniorToken(
    uint256 _amount,
    address _poolAddress,
    uint256 _tranche
  ) external onlyOwner {
    require(_amount > 0, "Must deposit more than zero");
    goldfinchDelegacy.purchaseJuniorToken(_amount, _poolAddress, _tranche);
    emit PurchaseJunior(_amount);
  }

  /**
   * @notice Sell junior token through delegacy to get repayments
   * @param _tokenId the ID of token to sell
   * @param _amount the amount to withdraw
   * @param _poolAddress the pool address to withdraw from
   */
  function sellJuniorToken(
    uint256 _tokenId,
    uint256 _amount,
    address _poolAddress
  ) external onlyOwner {
    require(_amount > 0, "Must sell more than zero");
    goldfinchDelegacy.sellJuniorToken(_tokenId, _amount, _poolAddress, percentageDURARepayment);
    emit SellSenior(_amount);
  }

  /**
   * @notice Purchase senior token through delegacy to get fidu inside the delegacy
   * @param _amount the amount of usdc to purchase by
   */
  function purchaseSeniorTokens(uint256 _amount) external onlyOwner {
    require(_amount > 0, "Must deposit more than zero");
    goldfinchDelegacy.purchaseSeniorTokens(_amount);
    emit PurchaseSenior(_amount);
  }

  /**
   * @notice Sell senior token through delegacy to redeem fidu
   * @param _amount the amount of fidu to sell
   */
  function sellSeniorTokens(uint256 _amount) external onlyOwner {
    require(_amount > 0, "Must sell more than zero");
    goldfinchDelegacy.sellSeniorTokens(_amount, percentageDURARepayment);
    emit SellSenior(_amount);
  }

  /**
   * @notice Migrate certain ERC20 to an address
   * @param _tokenAddress the token address to migrate
   * @param _to the address to transfer tokens to
   */
  function migrateERC20(address _tokenAddress, address _to) external onlyOwner whenPaused {
    uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
    IERC20(_tokenAddress).safeTransfer(_to, balance);
  }

  /**
   * @notice Migrate certain ERC721 of ID to an address
   * @param _tokenAddress the address of ERC721 token
   * @param _toAddress the address to transfer tokens to
   * @param _tokenId the token ID to transfer
   */
  function migrateERC721(
    address _tokenAddress,
    address _toAddress,
    uint256 _tokenId
  ) external onlyOwner whenPaused {
    IERC721(_tokenAddress).safeTransferFrom(address(this), _toAddress, _tokenId);
  }

  /**
   * @notice Transfer redemption fee to some other address
   * @param _to the address to transfer to
   */
  function transferRedemptionFee(address _to) external onlyOwner whenNotPaused {
    usdcCoin.safeTransfer(_to, redemptionFee);
    redemptionFee = 0;
  }

  /**
   * @notice Transfer the ownership of alloy CRWN and DURA token contract to some other address
   * @param _to the address to transfer ownership to
   */
  function transferAlloyxOwnership(address _to) external onlyOwner whenPaused {
    alloyxTokenDURA.transferOwnership(_to);
    alloyxTokenCRWN.transferOwnership(_to);
  }
}
