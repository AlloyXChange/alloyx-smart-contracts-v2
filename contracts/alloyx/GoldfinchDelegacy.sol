// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../goldfinch/interfaces/ITranchedPool.sol";
import "../goldfinch/interfaces/ISeniorPool.sol";
import "../goldfinch/interfaces/IPoolTokens.sol";
import "./interfaces/IGoldfinchDelegacy.sol";
import "./interfaces/ISortedGoldfinchTranches.sol";

/**
 * @title Goldfinch Delegacy
 * @notice Middle layer to communicate with goldfinch contracts
 * @author AlloyX
 */
contract GoldfinchDelegacy is IGoldfinchDelegacy, ERC721HolderUpgradeable, OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using SafeMath for uint256;

  uint256 public earningGfiFee;
  uint256 public repaymentFee;
  address private coreVaultAddress;
  mapping(uint256 => address) tokenDepositorMap;
  IERC20Upgradeable private usdcCoin;
  IERC20Upgradeable private gfiCoin;
  IERC20Upgradeable private fiduCoin;
  IPoolTokens private poolToken;
  ISeniorPool private seniorPool;
  ISortedGoldfinchTranches private sortedGoldfinchTranches;

  function initialize(
    address _usdcCoinAddress,
    address _fiduCoinAddress,
    address _gfiCoinAddress,
    address _poolTokenAddress,
    address _seniorPoolAddress,
    address _coreVaultAddress,
    address _sortedGoldfinchTranches
  ) public initializer {
    __Ownable_init();
    __ERC721Holder_init();
    usdcCoin = IERC20Upgradeable(_usdcCoinAddress);
    gfiCoin = IERC20Upgradeable(_gfiCoinAddress);
    fiduCoin = IERC20Upgradeable(_fiduCoinAddress);
    poolToken = IPoolTokens(_poolTokenAddress);
    seniorPool = ISeniorPool(_seniorPoolAddress);
    sortedGoldfinchTranches = ISortedGoldfinchTranches(_sortedGoldfinchTranches);
    coreVaultAddress = _coreVaultAddress;
  }

  /**
   * @notice If it is called from the vault
   */
  modifier fromVault() {
    require(coreVaultAddress == msg.sender, "The function must be called from vault");
    _;
  }

  /**
   * @notice Approve certain amount token of certain address to some other account
   * @param _account the address to approve
   * @param _amount the amount to approve
   * @param _tokenAddress the token address to approve
   */
  function approve(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external override fromVault {
    IERC20Upgradeable(_tokenAddress).approve(_account, _amount);
  }

  /**
   * @notice Fidu Value in Vault in term of USDC
   */
  function getFiduBalanceInUSDC() internal view returns (uint256) {
    return
      fiduToUSDC(
        fiduCoin.balanceOf(address(this)).mul(seniorPool.sharePrice()).div(fiduMantissa())
      );
  }

  /**
   * @notice convert USDC amount to FIDU
   */
  function usdcToFidu(uint256 amount) external view returns (uint256) {
    return seniorPool.getNumShares(amount);
  }

  /**
   * @notice USDC Value in Vault
   */
  function getUSDCBalance() public view returns (uint256) {
    return usdcCoin.balanceOf(address(this));
  }

  /**
   * @notice GFI Balance in Vault
   */
  function getGFIBalance() public view returns (uint256) {
    return gfiCoin.balanceOf(address(this));
  }

  /**
   * @notice USDC Value in Vault for investment
   */
  function getUSDCBalanceAvailableForInvestment() external view override returns (uint256) {
    return getUSDCBalance().sub(repaymentFee);
  }

  /**
   * @notice Delegacy Value in terms of USDC
   */
  function getGoldfinchDelegacyBalanceInUSDC() public view override returns (uint256) {
    uint256 delegacyValue = getFiduBalanceInUSDC().add(getUSDCBalance()).add(
      getGoldFinchPoolTokenBalanceInUSDC()
    );
    require(delegacyValue >= repaymentFee, "Vault value is less than the repayment fee collected");
    return delegacyValue.sub(repaymentFee);
  }

  /**
   * @notice Convert FIDU coins to USDC
   */
  function fiduToUSDC(uint256 amount) internal pure returns (uint256) {
    return amount.div(fiduMantissa().div(usdcMantissa()));
  }

  /**
   * @notice Fidu mantissa with 18 decimals
   */
  function fiduMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(18);
  }

  /**
   * @notice USDC mantissa with 6 decimals
   */
  function usdcMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(6);
  }

  /**
   * @notice Change the senior pool address
   * @param _seniorPool The address to change to
   */
  function changeSeniorPoolAddress(address _seniorPool) external onlyOwner {
    seniorPool = ISeniorPool(_seniorPool);
  }

  /**
   * @notice Change the pool token address
   * @param _poolToken The address to change to
   */
  function changePoolTokenAddress(address _poolToken) external onlyOwner {
    poolToken = IPoolTokens(_poolToken);
  }

  /**
   * @notice Change the vault address
   * @param _vaultAddress The address to change to
   */
  function changeVaultAddress(address _vaultAddress) external onlyOwner {
    coreVaultAddress = _vaultAddress;
  }

  /**
   * @notice Change sortedGoldfinchTranches address
   * @param _sortedGoldfinchTranchesAddress The address to change to
   */
  function changeSortedGoldfinchTranches(address _sortedGoldfinchTranchesAddress)
    external
    onlyOwner
  {
    sortedGoldfinchTranches = ISortedGoldfinchTranches(_sortedGoldfinchTranchesAddress);
  }

  /**
   * @notice Add the depositor and tokenId to the map
   * @param _tokenId The token ID to deposit
   * @param _depositor The address of the depositor
   */
  function addToDepositorMap(address _depositor, uint256 _tokenId) external override fromVault {
    tokenDepositorMap[_tokenId] = _depositor;
  }

  /**
   * @notice Get the tokenID array of depositor
   * @param _depositor The address of the depositor
   */
  function getTokensAvailableForWithdrawal(address _depositor)
    external
    view
    returns (uint256[] memory)
  {
    uint256 count = poolToken.balanceOf(address(this));
    uint256[] memory ids = new uint256[](getTokensAvailableCountForWithdrawal(_depositor));
    uint256 index = 0;
    for (uint256 i = 0; i < count; i++) {
      uint256 id = poolToken.tokenOfOwnerByIndex(address(this), i);
      if (tokenDepositorMap[id] == _depositor) {
        ids[index] = id;
        index += 1;
      }
    }
    return ids;
  }

  /**
   * @notice Get the token count of depositor
   * @param _depositor The address of the depositor
   */
  function getTokensAvailableCountForWithdrawal(address _depositor) public view returns (uint256) {
    uint256 count = poolToken.balanceOf(address(this));
    uint256 numOfTokens = 0;
    for (uint256 i = 0; i < count; i++) {
      uint256 id = poolToken.tokenOfOwnerByIndex(address(this), i);
      if (tokenDepositorMap[id] == _depositor) {
        numOfTokens += 1;
      }
    }
    return numOfTokens;
  }

  /**
   * @notice Check if the token of that ID is deposited by the depositor and valid for withdrawal
   * @param _depositor The address of the depositor
   * @param _tokenId The token ID to deposit
   */
  function isTokenIdValidForWithdrawal(address _depositor, uint256 _tokenId)
    public
    view
    returns (bool)
  {
    return
      tokenDepositorMap[_tokenId] == _depositor && poolToken.ownerOf(_tokenId) == address(this);
  }

  /**
   * @notice Send the token of the ID to address
   * @param _depositor The address to send to
   * @param _tokenId The token ID to deposit
   */
  function transferTokenToDepositor(address _depositor, uint256 _tokenId)
    external
    override
    fromVault
  {
    require(
      isTokenIdValidForWithdrawal(_depositor, _tokenId),
      "The token is not valid to withdraw"
    );
    poolToken.safeTransferFrom(address(this), _depositor, _tokenId);
    delete tokenDepositorMap[_tokenId];
  }

  /**
   * @notice GoldFinch PoolToken Value in Value in term of USDC
   */
  function getGoldFinchPoolTokenBalanceInUSDC() public view override returns (uint256) {
    uint256 total = 0;
    uint256 balance = poolToken.balanceOf(address(this));
    for (uint256 i = 0; i < balance; i++) {
      total = total.add(getJuniorTokenValue(poolToken.tokenOfOwnerByIndex(address(this), i)));
    }
    return total;
  }

  /**
   * @notice Using the Goldfinch contracts, read the principal, redeemed and redeemable values
   * @param _tokenID The backer NFT id
   */
  function getJuniorTokenValue(uint256 _tokenID) public view override returns (uint256) {
    IPoolTokens.TokenInfo memory tokenInfo = poolToken.getTokenInfo(_tokenID);
    uint256 principalAmount = tokenInfo.principalAmount;
    uint256 totalRedeemed = tokenInfo.principalRedeemed.add(tokenInfo.interestRedeemed);

    // now get the redeemable values for the given token
    address tranchedPoolAddress = tokenInfo.pool;
    ITranchedPool tranchedTokenContract = ITranchedPool(tranchedPoolAddress);
    (uint256 interestRedeemable, uint256 principalRedeemable) = tranchedTokenContract
      .availableToWithdraw(_tokenID);
    uint256 totalRedeemable = interestRedeemable;
    // only add principal here if there have been drawdowns otherwise it overstates the value
    if (principalRedeemable < principalAmount) {
      totalRedeemable.add(principalRedeemable);
    }
    return principalAmount.sub(totalRedeemed).add(totalRedeemable);
  }

  /**
   * @notice Purchase junior token through this delegacy to get pooltoken inside this delegacy
   * @param _amount the amount of usdc to purchase by
   * @param _poolAddress the pool address to buy from
   * @param _tranche the tranch id
   */
  function purchaseJuniorToken(
    uint256 _amount,
    address _poolAddress,
    uint256 _tranche
  ) external override fromVault {
    require(usdcCoin.balanceOf(address(this)) >= _amount, "Vault has insufficent stable coin");
    require(_amount > 0, "Must deposit more than zero");
    ITranchedPool juniorPool = ITranchedPool(_poolAddress);
    juniorPool.deposit(_amount, _tranche);
  }

  /**
   * @notice Purchase junior token through this delegacy to get pooltoken inside this delegacy
   * @param _amount the amount of usdc to purchase by
   */
  function purchaseJuniorTokenOnBestTranch(uint256 _amount) external override fromVault {
    require(usdcCoin.balanceOf(address(this)) >= _amount, "Vault has insufficent stable coin");
    require(_amount > 0, "Must deposit more than zero");
    address tranch = sortedGoldfinchTranches.getTop(1)[0];
    ITranchedPool juniorPool = ITranchedPool(tranch);
    juniorPool.deposit(_amount, 1);
  }

  /**
   * @notice Sell junior token through this delegacy to get repayments
   * @param _tokenId the ID of token to sell
   * @param _amount the amount to withdraw
   * @param _poolAddress the pool address to withdraw from
   * @param _percentageBronzeRepayment the repayment fee for bronze token in percentage
   */
  function sellJuniorToken(
    uint256 _tokenId,
    uint256 _amount,
    address _poolAddress,
    uint256 _percentageBronzeRepayment
  ) external override fromVault {
    require(_amount > 0, "Must deposit more than zero");
    ITranchedPool juniorPool = ITranchedPool(_poolAddress);
    (uint256 principal, uint256 interest) = juniorPool.withdraw(_tokenId, _amount);
    uint256 fee = principal.add(interest).mul(_percentageBronzeRepayment).div(100);
    repaymentFee = repaymentFee.add(fee);
  }

  /**
   * @notice Purchase senior token through this delegacy to get FIDU inside this delegacy
   * @param _amount the amount of USDC to purchase by
   */
  function purchaseSeniorTokens(uint256 _amount) external override fromVault {
    require(usdcCoin.balanceOf(address(this)) >= _amount, "Vault has insufficent stable coin");
    require(_amount > 0, "Must deposit more than zero");
    seniorPool.deposit(_amount);
  }

  /**
   * @notice Purchase senior token through this delegacy to get FIDU inside this delegacy
   * @param _amount the amount of USDC to purchase by
   * @param _to the receiver of fidu
   */
  function purchaseSeniorTokensAndTransferTo(uint256 _amount, address _to)
    external
    override
    fromVault
  {
    require(usdcCoin.balanceOf(address(this)) >= _amount, "Vault has insufficent stable coin");
    require(_amount > 0, "Must deposit more than zero");
    uint256 fiduAmount = seniorPool.deposit(_amount);
    fiduCoin.safeTransfer(_to, fiduAmount);
  }

  /**
   * @notice sell senior token through delegacy to redeem fidu
   * @param _amount the amount of fidu to sell
   * @param _percentageBronzeRepayment the repayment fee for bronze token in percentage
   */
  function sellSeniorTokens(uint256 _amount, uint256 _percentageBronzeRepayment)
    external
    override
    fromVault
  {
    require(fiduCoin.balanceOf(address(this)) >= _amount, "Vault has insufficent fidu coin");
    require(_amount > 0, "Must deposit more than zero");
    uint256 usdcAmount = seniorPool.withdrawInFidu(_amount);
    uint256 fee = usdcAmount.mul(_percentageBronzeRepayment).div(100);
    repaymentFee = repaymentFee.add(fee);
  }

  /**
   * @notice Claim certain amount of reward token based on alloy silver token, the method will burn the silver token of
   * the amount of message sender, and transfer reward token to message sender
   * @param _rewardee the address of rewardee
   * @param _amount the amount of silver tokens used to claim
   * @param _totalSupply total claimable and claimed silver tokens of all stakeholders
   * @param _percentageFee the earning fee for redeeming silver token in percentage in terms of GFI
   */
  function claimReward(
    address _rewardee,
    uint256 _amount,
    uint256 _totalSupply,
    uint256 _percentageFee
  ) external override fromVault {
    require(
      getGFIBalance() >= earningGfiFee,
      "The GFI in the delegacy is less than the GFI fee collected"
    );
    uint256 amountToReward = _amount.mul(getGFIBalance().sub(earningGfiFee)).div(_totalSupply);
    uint256 fee = amountToReward.mul(_percentageFee).div(100);
    gfiCoin.safeTransfer(_rewardee, amountToReward.sub(fee));
    earningGfiFee = earningGfiFee.add(fee);
  }

  /**
   * @notice Get gfi amount that should be transfered to the claimer for the amount of CRWN
   * @param _amount the amount of silver tokens used to claim
   * @param _totalSupply total claimable and claimed silver tokens of all stakeholders
   * @param _percentageFee the earning fee for redeeming silver token in percentage in terms of GFI
   */
  function getRewardAmount(
    uint256 _amount,
    uint256 _totalSupply,
    uint256 _percentageFee
  ) external view override fromVault returns (uint256) {
    uint256 amountToReward = _amount.mul(getGFIBalance().sub(earningGfiFee)).div(_totalSupply);
    uint256 fee = amountToReward.mul(_percentageFee).div(100);
    return amountToReward.sub(fee);
  }

  /**
   * @notice Validates the Pooltoken to be deposited and get the USDC value of the token
   * @param _tokenAddress the Pooltoken address
   * @param _depositor the person to deposit
   * @param _tokenID the ID of the Pooltoken
   */
  function validatesTokenToDepositAndGetPurchasePrice(
    address _tokenAddress,
    address _depositor,
    uint256 _tokenID
  ) external override fromVault returns (uint256) {
    require(_tokenAddress == address(poolToken), "Not Goldfinch Pool Token");
    require(isValidPool(_tokenID) == true, "Not a valid pool");
    require(IERC721(_tokenAddress).ownerOf(_tokenID) == _depositor, "User does not own this token");
    require(
      poolToken.getApproved(_tokenID) == msg.sender,
      "User has not approved the vault for this token"
    );
    uint256 purchasePrice = getJuniorTokenValue(_tokenID);
    require(purchasePrice > 0, "The amount of stable coin to get is not larger than 0");
    return purchasePrice;
  }

  /**
   * @notice Pay USDC tokens to account
   * @param _to the address to pay to
   * @param _amount the amount to pay
   */
  function payUsdc(address _to, uint256 _amount) external override fromVault {
    usdcCoin.safeTransfer(_to, _amount);
  }

  /**
   * @notice Using the PoolTokens interface, check if this is a valid pool
   * @param _tokenID The backer NFT id
   */
  function isValidPool(uint256 _tokenID) public view returns (bool) {
    IPoolTokens.TokenInfo memory tokenInfo = poolToken.getTokenInfo(_tokenID);
    address tranchedPool = tokenInfo.pool;
    return poolToken.validPool(tranchedPool);
  }

  /**
   * @notice Get the IDs of Pooltokens of an addresss
   * @param _owner the address to get IDs of
   */
  function getGoldfinchTokenIdsOf(address _owner) internal view returns (uint256[] memory) {
    uint256 count = poolToken.balanceOf(_owner);
    uint256[] memory ids = new uint256[](count);
    for (uint256 i = 0; i < count; i++) {
      ids[i] = poolToken.tokenOfOwnerByIndex(_owner, i);
    }
    return ids;
  }

  /**
   * @notice Migrate Pooltoken of ID to an address
   * @param _toAddress the address to transfer tokens to
   * @param _tokenId the token ID to transfer
   */
  function migrateGoldfinchPoolTokens(address _toAddress, uint256 _tokenId) public onlyOwner {
    poolToken.safeTransferFrom(address(this), _toAddress, _tokenId);
  }

  /**
   * @notice Migrate all Pooltokens to an address
   * @param _toAddress the address to transfer tokens to
   */
  function migrateAllGoldfinchPoolTokens(address _toAddress) external onlyOwner {
    uint256[] memory tokenIds = getGoldfinchTokenIdsOf(address(this));
    for (uint256 i = 0; i < tokenIds.length; i++) {
      migrateGoldfinchPoolTokens(_toAddress, tokenIds[i]);
    }
  }

  /**
   * @notice Migrate certain ERC20 to an address
   * @param _tokenAddress the token address to migrate
   * @param _to the address to transfer tokens to
   */
  function migrateERC20(address _tokenAddress, address _to) external onlyOwner {
    uint256 balance = IERC20Upgradeable(_tokenAddress).balanceOf(address(this));
    IERC20Upgradeable(_tokenAddress).safeTransfer(_to, balance);
  }

  /**
   * @notice Transfer repayment fee to some other address
   * @param _to the address to transfer tokens to
   */
  function transferRepaymentFee(address _to) external onlyOwner {
    usdcCoin.safeTransfer(_to, repaymentFee);
    repaymentFee = 0;
  }

  /**
   * @notice Transfer earning gfi fee to some other address
   * @param _to the address to transfer tokens to
   */
  function transferEarningGfiFee(address _to) external onlyOwner {
    gfiCoin.safeTransfer(_to, earningGfiFee);
    earningGfiFee = 0;
  }
}
