// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../AlloyxTokenBronze.sol";
import "../AlloyxTokenSilver.sol";
import "../IGoldfinchDelegacy.sol";


/**
 * @title AlloyX Vault
 * @notice Initial vault for AlloyX. This vault holds loan tokens generated on Goldfinch
 * and emits AlloyTokens when a liquidity provider deposits supported stable coins.
 * @author AlloyX
 */
contract AlloyxVaultV4_0 is ERC721Holder, Ownable, Pausable {
  using SafeERC20 for IERC20;
  using SafeERC20 for AlloyxTokenBronze;
  using SafeMath for uint256;
  struct StakeInfo {
    uint256 amount;
    uint256 since;
  }
  bool private vaultStarted;
  IERC20 private usdcCoin;
  AlloyxTokenBronze private alloyxTokenBronze;
  AlloyxTokenSilver private alloyxTokenSilver;
  IGoldfinchDelegacy private goldfinchDelegacy;
  address[] internal stakeholders;
  mapping(address => StakeInfo) stakesMapping;
  mapping(address => uint256) pastRedeemableReward;
  uint percentageRewardPerYear = 2;
  uint percentageBronzeRedemption = 1;
  uint percentageBronzeRepayment = 2;
  uint percentageSilverEarning = 10;
  uint public vaultFee = 0;

  event DepositStable(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event DepositNFT(address _tokenAddress, address _tokenSender, uint256 _tokenID);
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

  constructor(
    address _alloyxBronzeAddress,
    address _alloyxSilverAddress,
    address _usdcCoinAddress,
    address _goldfinchDelegacy
  ) {
    alloyxTokenBronze = AlloyxTokenBronze(_alloyxBronzeAddress);
    alloyxTokenSilver = AlloyxTokenSilver(_alloyxSilverAddress);
    usdcCoin = IERC20(_usdcCoinAddress);
    goldfinchDelegacy = IGoldfinchDelegacy(_goldfinchDelegacy);
    vaultStarted = false;
  }

  function totalReward() public view returns (uint256) {
    uint256 reward = 0;
    for (uint256 s = 0; s < stakeholders.length; s += 1) {
      reward = reward.add(claimableSilverToken(stakeholders[s]));
    }
    reward = reward.add(alloyxTokenSilver.totalSupply());
    return reward;
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
      stakeholders[s] = stakeholders[stakeholders.length - 1];
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
  function createStake(uint256 _stake) internal {
    if (stakesMapping[msg.sender].amount == 0) addStakeholder(msg.sender);
    addPastRedeemableReward(msg.sender,stakesMapping[msg.sender]);
    stakesMapping[msg.sender] = StakeInfo(_stake, block.timestamp);
  }

  function addStake(address _staker, uint256 _stake) internal {
    if (stakesMapping[_staker].amount == 0) addStakeholder(_staker);
    addPastRedeemableReward(_staker, stakesMapping[_staker]);
    stakesMapping[_staker] = StakeInfo(stakesMapping[_staker].amount.add(_stake), block.timestamp);
  }

  function removeStake(address _staker, uint256 _stake) internal {
    require(stakeOf(_staker).amount >= _stake, "User has insufficient dura coin staked");
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

  function stake(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    addStake(msg.sender, _amount);
    alloyxTokenBronze.safeTransferFrom(msg.sender,address(this), _amount);
    return true;
  }

  function unstake(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    removeStake(msg.sender, _amount);
    alloyxTokenBronze.safeTransfer(msg.sender, _amount);
    return true;
  }

  /**
   * @notice A method for a stakeholder to clear a stake.
   */
  function clearStake() internal {
    createStake(0);
  }

  /**
   * @notice A method for a stakeholder to clear a stake with reward
   * @param _reward the leftover reward the staker owns
   */
  function clearStakeWithRewardLeft(uint256 _reward) internal {
    createStake(0);
    pastRedeemableReward[msg.sender] = _reward;
  }


  function calculateRewardFromStake(StakeInfo memory _stake) internal view returns (uint256) {
    return _stake.amount.mul(block.timestamp.sub(_stake.since)).mul(percentageRewardPerYear).div(100).div(365 days);
  }


  function approveDelegacy(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external onlyOwner {
    goldfinchDelegacy.approve(_tokenAddress, _account, _amount);
  }

  /**
   * @notice Alloy Brown Token Value in terms of USDC
   */
  function getAlloyxBronzeTokenBalanceInUSDC() public view returns (uint256) {
    return getUSDCBalance().add(goldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()).sub(vaultFee);
  }

  /**
   * @notice USDC Value in Vault
   */
  function getUSDCBalance() internal view returns (uint256) {
    return usdcCoin.balanceOf(address(this));
  }

  /**
   * @notice Convert Alloyx Bronze to USDC amount
   */
  function alloyxBronzeToUSDC(uint256 amount) public view returns (uint256) {
    uint256 alloyBronzeTotalSupply = alloyxTokenBronze.totalSupply();
    uint256 totalVaultAlloyxBronzeValueInUSDC = getAlloyxBronzeTokenBalanceInUSDC();
    return amount.mul(totalVaultAlloyxBronzeValueInUSDC).div(alloyBronzeTotalSupply);
  }

  /**
   * @notice Convert USDC Amount to Alloyx Bronze
   */
  function usdcToAlloyxBronze(uint256 amount) public view returns (uint256) {
    uint256 alloyBronzeTotalSupply = alloyxTokenBronze.totalSupply();
    uint256 totalVaultAlloyxBronzeValueInUSDC = getAlloyxBronzeTokenBalanceInUSDC();
    return amount.mul(alloyBronzeTotalSupply).div(totalVaultAlloyxBronzeValueInUSDC);
  }

  function alloyMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(18);
  }

  function setPercentageRewardPerYear(uint _percentageRewardPerYear) external onlyOwner {
    percentageRewardPerYear = _percentageRewardPerYear;
  }

  function setPercentageBronzeRedemption(uint _percentageBronzeRedemption) external onlyOwner {
    percentageBronzeRedemption = _percentageBronzeRedemption;
  }

  function setPercentageBronzeRepayment(uint _percentageBronzeRepayment) external onlyOwner {
    percentageBronzeRepayment = _percentageBronzeRepayment;
  }

  function setPercentageSilverEarning(uint _percentageSilverEarning) external onlyOwner {
    percentageSilverEarning = _percentageSilverEarning;
  }


  function usdcMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(6);
  }

  function changeAlloyxBronzeAddress(address _alloyxAddress) external onlyOwner {
    alloyxTokenBronze = AlloyxTokenBronze(_alloyxAddress);
  }

  modifier whenVaultStarted() {
    require(vaultStarted, "Vault has not start accepting deposits");
    _;
  }

  modifier whenVaultNotStarted() {
    require(!vaultStarted, "Vault has already start accepting deposits");
    _;
  }

  function changeGoldfinchDelegacyAddress(address _goldfinchDelegacy) external onlyOwner {
    goldfinchDelegacy = IGoldfinchDelegacy(_goldfinchDelegacy);
  }

  function pause() external onlyOwner whenNotPaused {
    _pause();
  }

  function unpause() external onlyOwner whenPaused {
    _unpause();
  }

  /**
   * @notice Initialize by minting the alloy brown tokens to owner
   */
  function startVaultOperation() external onlyOwner whenVaultNotStarted returns (bool) {
    uint256 totalBalanceInUSDC = getAlloyxBronzeTokenBalanceInUSDC();
    require(totalBalanceInUSDC > 0, "Vault must have positive value before start");
    alloyxTokenBronze.mint(
      address(this),
      totalBalanceInUSDC.mul(alloyMantissa()).div(usdcMantissa())
    );
    vaultStarted = true;
    return true;
  }

  /**
   * @notice An Alloy token holder can deposit their tokens and redeem them for USDC
   * @param _tokenAmount Number of Alloy Tokens
   */
  function depositAlloyxBronzeTokens(uint256 _tokenAmount)
    external
    whenNotPaused
    whenVaultStarted
    returns (bool)
  {
    require(
      alloyxTokenBronze.balanceOf(msg.sender) >= _tokenAmount,
      "User has insufficient alloyx coin"
    );
    require(
      alloyxTokenBronze.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient alloyx coin"
    );
    uint256 amountToWithdraw = alloyxBronzeToUSDC(_tokenAmount);
    uint256 withdrawalFee=amountToWithdraw.mul(percentageBronzeRedemption).div(100);
    require(amountToWithdraw > 0, "The amount of stable coin to get is not larger than 0");
    require(
      usdcCoin.balanceOf(address(this)) >= amountToWithdraw,
      "The vault does not have sufficient stable coin"
    );
    alloyxTokenBronze.burn(msg.sender, _tokenAmount);
    usdcCoin.safeTransfer(msg.sender, amountToWithdraw.sub(withdrawalFee));
    vaultFee=vaultFee.add(withdrawalFee);
    emit DepositAlloyx(address(alloyxTokenBronze), msg.sender, _tokenAmount);
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
    returns (bool)
  {
    require(usdcCoin.balanceOf(msg.sender) >= _tokenAmount, "User has insufficient stable coin");
    require(
      usdcCoin.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient stable coin"
    );
    uint256 amountToMint = usdcToAlloyxBronze(_tokenAmount);
    require(amountToMint > 0, "The amount of alloyx bronze coin to get is not larger than 0");
    usdcCoin.safeTransferFrom(msg.sender, address(goldfinchDelegacy), _tokenAmount);
    alloyxTokenBronze.mint(msg.sender, amountToMint);
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
  returns (bool)
  {
    require(usdcCoin.balanceOf(msg.sender) >= _tokenAmount, "User has insufficient stable coin");
    require(
      usdcCoin.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient stable coin"
    );
    uint256 amountToMint = usdcToAlloyxBronze(_tokenAmount);
    require(amountToMint > 0, "The amount of alloyx bronze coin to get is not larger than 0");
    usdcCoin.safeTransferFrom(msg.sender, address(this), _tokenAmount);
    alloyxTokenBronze.mint(address(this), amountToMint);
    addStake(msg.sender,amountToMint);
    emit DepositStable(address(usdcCoin), msg.sender, amountToMint);
    emit Mint(address(this), amountToMint);
    return true;
  }

  /**
   * @notice A Junior token holder can deposit their NFT for stable coin
   * @param _tokenAddress NFT Address
   * @param _tokenID NFT ID
   */
  function depositNFTToken(address _tokenAddress, uint256 _tokenID)
    external
    whenNotPaused
    whenVaultStarted
    returns (bool)
  {
    uint256 purchasePrice = goldfinchDelegacy.validatesTokenToDepositAndGetPurchasePrice(
      _tokenAddress,
      msg.sender,
      _tokenID
    );
    IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(goldfinchDelegacy), _tokenID);
    goldfinchDelegacy.payUsdc(msg.sender, purchasePrice);
    emit DepositNFT(_tokenAddress, msg.sender, _tokenID);
    return true;
  }


  function claimableSilverToken(address receiver) public view returns (uint256) {
    StakeInfo memory stake = stakeOf(receiver);
    return pastRedeemableReward[receiver] + calculateRewardFromStake(stake);
  }

  function totalClaimableSilverToken() public view returns (uint256) {
    uint256 total = 0;
    for (uint256 i = 0; i < stakeholders.length; i++) {
      total=total.add(claimableSilverToken(stakeholders[i]));
    }
    return total;
  }

  function totalClaimableAndClaimedSilverToken() public view returns (uint256) {
    return totalClaimableSilverToken().add(alloyxTokenSilver.totalSupply());
  }

  function claimAllAlloyxSilver() external whenNotPaused whenVaultStarted returns (bool) {
    uint256 reward = claimableSilverToken(msg.sender);
    alloyxTokenSilver.mint(msg.sender, reward);
    clearStakeWithRewardLeft(0);
    emit Claim(msg.sender, reward);
    return true;
  }


  function claimAlloyxSilver(uint256 _amount)
  external
  whenNotPaused
  whenVaultStarted
  returns (bool)
  {
    uint256 allReward = claimableSilverToken(msg.sender);
    require(allReward >= _amount, "User has claimed more than he's entitled");
    alloyxTokenSilver.mint(msg.sender, _amount);
    clearStakeWithRewardLeft(allReward.sub(_amount));
    emit Claim(msg.sender, _amount);
    return true;
  }

  function claimReward(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    require(alloyxTokenSilver.balanceOf(address(msg.sender)) >= _amount, "Balance of crown coin must be larger than the amount to claim");
    goldfinchDelegacy.claimReward(msg.sender,_amount,totalClaimableAndClaimedSilverToken(),percentageSilverEarning);
    alloyxTokenSilver.burn(msg.sender,_amount);
    emit Reward(msg.sender, _amount);
    return true;
  }


  function destroy() external onlyOwner whenPaused {
    require(usdcCoin.balanceOf(address(this)) == 0, "Balance of stable coin must be 0");

    address payable addr = payable(address(owner()));
    selfdestruct(addr);
  }

  function purchaseJuniorToken(
    uint256 amount,
    address poolAddress,
    uint256 tranche
  ) external onlyOwner {
    require(amount > 0, "Must deposit more than zero");
    goldfinchDelegacy.purchaseJuniorToken(amount, poolAddress, tranche);
    emit PurchaseJunior(amount);
  }

  function sellJuniorToken(uint256 tokenId,uint256 amount,address poolAddress) external onlyOwner {
    require(amount > 0, "Must sell more than zero");
    goldfinchDelegacy.sellJuniorToken(tokenId,amount,poolAddress,percentageBronzeRepayment);
    emit SellSenior(amount);
  }

  function purchaseSeniorTokens(uint256 amount) external onlyOwner {
    require(amount > 0, "Must deposit more than zero");
    goldfinchDelegacy.purchaseSeniorTokens(amount);
    emit PurchaseSenior(amount);
  }

  function sellSeniorTokens(uint256 amount) external onlyOwner {
    require(amount > 0, "Must sell more than zero");
    goldfinchDelegacy.sellSeniorTokens(amount,percentageBronzeRepayment);
    emit SellSenior(amount);
  }

  function migrateERC20(address _tokenAddress, address payable _to) external onlyOwner whenPaused {
    uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
    IERC20(_tokenAddress).safeTransfer(_to, balance);
  }

  function transferAlloyxOwnership(address _to) external onlyOwner whenPaused {
    alloyxTokenBronze.transferOwnership(_to);
  }
}
