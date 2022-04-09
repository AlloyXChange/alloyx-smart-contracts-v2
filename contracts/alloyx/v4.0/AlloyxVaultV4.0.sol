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
  uint256 percentageRewardPerYear = 2;
  uint256 percentageBronzeRedemption = 1;
  uint256 percentageBronzeRepayment = 2;
  uint256 percentageSilverEarning = 10;
  uint256 public redemptionFee = 0;

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
   * @notice Check if an address is a stakeholder.
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
   * @notice Add a stakeholder.
   * @param _stakeholder The stakeholder to add.
   */
  function addStakeholder(address _stakeholder) internal {
    (bool _isStakeholder, ) = isStakeholder(_stakeholder);
    if (!_isStakeholder) stakeholders.push(_stakeholder);
  }

  /**
   * @notice Remove a stakeholder.
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
   * @notice Retrieve the stake for a stakeholder.
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
    addPastRedeemableReward(msg.sender, stakesMapping[msg.sender]);
    stakesMapping[msg.sender] = StakeInfo(_stake, block.timestamp);
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

  /**
   * @notice Stake more into the vault, which will cause the user's bronze token to transfer to vault
   * @param _amount the amount the message sender intending to stake in
   */
  function stake(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    addStake(msg.sender, _amount);
    alloyxTokenBronze.safeTransferFrom(msg.sender, address(this), _amount);
    return true;
  }

  /**
   * @notice Unstake some from the vault, which will cause the vault to transfer bronze token back to message sender
   * @param _amount the amount the message sender intending to unstake
   */
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
   * @notice A method for a stakeholder to clear a stake with some leftover reward
   * @param _reward the leftover reward the staker owns
   */
  function clearStakeWithRewardLeft(uint256 _reward) internal {
    createStake(0);
    pastRedeemableReward[msg.sender] = _reward;
  }

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
   * @notice Claimable silver token amount of an address
   * @param _receiver the address of receiver
   */
  function claimableSilverToken(address _receiver) public view returns (uint256) {
    StakeInfo memory stake = stakeOf(_receiver);
    return pastRedeemableReward[_receiver] + calculateRewardFromStake(stake);
  }

  /**
   * @notice Total claimable silver tokens of all stakeholders
   */
  function totalClaimableSilverToken() public view returns (uint256) {
    uint256 total = 0;
    for (uint256 i = 0; i < stakeholders.length; i++) {
      total = total.add(claimableSilverToken(stakeholders[i]));
    }
    return total;
  }

  /**
   * @notice Total claimable and claimed silver tokens of all stakeholders
   */
  function totalClaimableAndClaimedSilverToken() public view returns (uint256) {
    return totalClaimableSilverToken().add(alloyxTokenSilver.totalSupply());
  }

  /**
   * @notice Claim all alloy silver tokens of the message sender, the method will mint the silver token of the claimable
   * amount to message sender, and clear the past rewards to zero
   */
  function claimAllAlloyxSilver() external whenNotPaused whenVaultStarted returns (bool) {
    uint256 reward = claimableSilverToken(msg.sender);
    alloyxTokenSilver.mint(msg.sender, reward);
    clearStakeWithRewardLeft(0);
    emit Claim(msg.sender, reward);
    return true;
  }

  /**
   * @notice Claim certain amount of alloy silver tokens of the message sender, the method will mint the silver token of
   * the claimable amount to message sender, and clear the past rewards to the remainder
   * @param _amount the amount to claim
   */
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

  /**
   * @notice Claim certain amount of reward token based on alloy silver token, the method will burn the silver token of
   * the amount of message sender, and transfer reward token to message sender
   * @param _amount the amount to claim
   */
  function claimReward(uint256 _amount) external whenNotPaused whenVaultStarted returns (bool) {
    require(
      alloyxTokenSilver.balanceOf(address(msg.sender)) >= _amount,
      "Balance of crown coin must be larger than the amount to claim"
    );
    goldfinchDelegacy.claimReward(
      msg.sender,
      _amount,
      totalClaimableAndClaimedSilverToken(),
      percentageSilverEarning
    );
    alloyxTokenSilver.burn(msg.sender, _amount);
    emit Reward(msg.sender, _amount);
    return true;
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
   * @notice Alloy Bronze Token Value in terms of USDC
   */
  function getAlloyxBronzeTokenBalanceInUSDC() public view returns (uint256) {
    uint256 totalValue = getUSDCBalance().add(
      goldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()
    );
    require(
      totalValue > redemptionFee,
      "the value of vault is not larger than redemption fee, something went wrong"
    );
    return
      getUSDCBalance().add(goldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC()).sub(
        redemptionFee
      );
  }

  /**
   * @notice USDC Value in Vault
   */
  function getUSDCBalance() internal view returns (uint256) {
    return usdcCoin.balanceOf(address(this));
  }

  /**
   * @notice Convert Alloyx Bronze to USDC amount
   * @param _amount the amount of bronze token to convert to usdc
   */
  function alloyxBronzeToUSDC(uint256 _amount) public view returns (uint256) {
    uint256 alloyBronzeTotalSupply = alloyxTokenBronze.totalSupply();
    uint256 totalVaultAlloyxBronzeValueInUSDC = getAlloyxBronzeTokenBalanceInUSDC();
    return _amount.mul(totalVaultAlloyxBronzeValueInUSDC).div(alloyBronzeTotalSupply);
  }

  /**
   * @notice Convert USDC Amount to Alloyx Bronze
   * @param _amount the amount of usdc to convert to bronze token
   */
  function usdcToAlloyxBronze(uint256 _amount) public view returns (uint256) {
    uint256 alloyBronzeTotalSupply = alloyxTokenBronze.totalSupply();
    uint256 totalVaultAlloyxBronzeValueInUSDC = getAlloyxBronzeTokenBalanceInUSDC();
    return _amount.mul(alloyBronzeTotalSupply).div(totalVaultAlloyxBronzeValueInUSDC);
  }

  /**
   * @notice Set percentageRewardPerYear which is the reward per year in percentage
   * @param _percentageRewardPerYear the reward per year in percentage
   */
  function setPercentageRewardPerYear(uint256 _percentageRewardPerYear) external onlyOwner {
    percentageRewardPerYear = _percentageRewardPerYear;
  }

  /**
   * @notice Set percentageBronzeRedemption which is the redemption fee for bronze token in percentage
   * @param _percentageBronzeRedemption the redemption fee for bronze token in percentage
   */
  function setPercentageBronzeRedemption(uint256 _percentageBronzeRedemption) external onlyOwner {
    percentageBronzeRedemption = _percentageBronzeRedemption;
  }

  /**
   * @notice Set percentageBronzeRepayment which is the repayment fee for bronze token in percentage
   * @param _percentageBronzeRepayment the repayment fee for bronze token in percentage
   */
  function setPercentageBronzeRepayment(uint256 _percentageBronzeRepayment) external onlyOwner {
    percentageBronzeRepayment = _percentageBronzeRepayment;
  }

  /**
   * @notice Set percentageSilverEarning which is the earning fee for redeeming silver token in percentage in terms of gfi
   * @param _percentageSilverEarning the earning fee for redeeming silver token in percentage in terms of gfi
   */
  function setPercentageSilverEarning(uint256 _percentageSilverEarning) external onlyOwner {
    percentageSilverEarning = _percentageSilverEarning;
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
   * @notice Change bronze token address
   * @param _alloyxAddress the address to change to
   */
  function changeAlloyxBronzeAddress(address _alloyxAddress) external onlyOwner {
    alloyxTokenBronze = AlloyxTokenBronze(_alloyxAddress);
  }

  function changeGoldfinchDelegacyAddress(address _goldfinchDelegacy) external onlyOwner {
    goldfinchDelegacy = IGoldfinchDelegacy(_goldfinchDelegacy);
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
    uint256 withdrawalFee = amountToWithdraw.mul(percentageBronzeRedemption).div(100);
    require(amountToWithdraw > 0, "The amount of stable coin to get is not larger than 0");
    require(
      usdcCoin.balanceOf(address(this)) >= amountToWithdraw,
      "The vault does not have sufficient stable coin"
    );
    alloyxTokenBronze.burn(msg.sender, _tokenAmount);
    usdcCoin.safeTransfer(msg.sender, amountToWithdraw.sub(withdrawalFee));
    redemptionFee = redemptionFee.add(withdrawalFee);
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
    addStake(msg.sender, amountToMint);
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
    goldfinchDelegacy.sellJuniorToken(_tokenId, _amount, _poolAddress, percentageBronzeRepayment);
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
    goldfinchDelegacy.sellSeniorTokens(_amount, percentageBronzeRepayment);
    emit SellSenior(_amount);
  }

  /**
   * @notice Destroy the contract
   */
  function destroy() external onlyOwner whenPaused {
    require(usdcCoin.balanceOf(address(this)) == 0, "Balance of stable coin must be 0");

    address payable addr = payable(address(owner()));
    selfdestruct(addr);
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
   * @notice Transfer redemption fee to some other address
   * @param _to the address to transfer to
   */
  function transferRedemptionFee(address _to) external onlyOwner whenNotPaused {
    usdcCoin.safeTransfer(_to, redemptionFee);
    redemptionFee = 0;
  }

  /**
   * @notice Transfer the ownership of alloy silver and bronze token contract to some other address
   * @param _to the address to transfer ownership to
   */
  function transferAlloyxOwnership(address _to) external onlyOwner whenPaused {
    alloyxTokenBronze.transferOwnership(_to);
    alloyxTokenSilver.transferOwnership(_to);
  }
}
