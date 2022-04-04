// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../goldfinch/interfaces/ITranchedPool.sol";
import "../goldfinch/interfaces/ISeniorPool.sol";
import "../goldfinch/interfaces/IPoolTokens.sol";
import "./IGoldfinchDelegacy.sol";

/**
 * @title Goldfinch Delegacy
 * @notice Middle layer to communicate with goldfinch contracts
 * @author AlloyX
 */
contract GoldfinchDelegacy is IGoldfinchDelegacy, ERC721Holder, Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  IERC20 private usdcCoin;
  IERC20 private gfiCoin;
  IERC20 private fiduCoin;
  IPoolTokens private poolToken;
  ISeniorPool private seniorPool;
  address private coreVaultAddress;
  uint public earningGfiFee =0;
  uint public repaymentFee =0;

  constructor(
    address _usdcCoinAddress,
    address _fiduCoinAddress,
    address _gfiCoinAddress,
    address _poolTokenAddress,
    address _seniorPoolAddress,
    address _coreVaultAddress
  ) {
    usdcCoin = IERC20(_usdcCoinAddress);
    gfiCoin = IERC20(_gfiCoinAddress);
    fiduCoin = IERC20(_fiduCoinAddress);
    poolToken = IPoolTokens(_poolTokenAddress);
    seniorPool = ISeniorPool(_seniorPoolAddress);
    coreVaultAddress = _coreVaultAddress;
  }

  modifier fromVault() {
    require(coreVaultAddress == msg.sender, "The function must be called from vault");
    _;
  }

  function approve(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external override fromVault {
    IERC20(_tokenAddress).approve(_account, _amount);
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
   * @notice Delegacy Value in terms of USDC
   */
  function getGoldfinchDelegacyBalanceInUSDC() public view override returns (uint256) {
    return getFiduBalanceInUSDC().add(getUSDCBalance()).add(getGoldFinchPoolTokenBalanceInUSDC()).sub(repaymentFee);
  }

  function fiduToUSDC(uint256 amount) internal pure returns (uint256) {
    return amount.div(fiduMantissa().div(usdcMantissa()));
  }

  function fiduMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(18);
  }

  function usdcMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(6);
  }

  function changeSeniorPoolAddress(address _seniorPool) external onlyOwner {
    seniorPool = ISeniorPool(_seniorPool);
  }

  function changePoolTokenAddress(address _poolToken) external onlyOwner {
    poolToken = IPoolTokens(_poolToken);
  }

  /**
   * @notice GoldFinch PoolToken Value in Value in term of USDC
   */
  function getGoldFinchPoolTokenBalanceInUSDC() internal view returns (uint256) {
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
  function getJuniorTokenValue(uint256 _tokenID) public view returns (uint256) {
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

  function purchaseJuniorToken(
    uint256 amount,
    address poolAddress,
    uint256 tranche
  ) external override fromVault {
    require(usdcCoin.balanceOf(address(this)) >= amount, "Vault has insufficent stable coin");
    require(amount > 0, "Must deposit more than zero");
    ITranchedPool juniorPool = ITranchedPool(poolAddress);
    juniorPool.deposit(amount, tranche);
  }

  function sellJuniorToken(uint256 tokenId, uint256 amount,address poolAddress ,uint256 percentageBronzeRepayment) external override fromVault {
    require(fiduCoin.balanceOf(address(this)) >= amount, "Vault has insufficent fidu coin");
    require(amount > 0, "Must deposit more than zero");
    ITranchedPool juniorPool = ITranchedPool(poolAddress);
    (uint256 principal,uint256 interest) = juniorPool.withdraw(tokenId, amount);
    uint256 fee=principal.add(interest).mul(percentageBronzeRepayment).div(100);
    repaymentFee=repaymentFee.add(fee);
  }

  function purchaseSeniorTokens(uint256 amount) external override fromVault {
    require(usdcCoin.balanceOf(address(this)) >= amount, "Vault has insufficent stable coin");
    require(amount > 0, "Must deposit more than zero");
    seniorPool.deposit(amount);
  }

  function sellSeniorTokens(uint256 amount ,uint256 percentageBronzeRepayment) external override fromVault {
    require(fiduCoin.balanceOf(address(this)) >= amount, "Vault has insufficent fidu coin");
    require(amount > 0, "Must deposit more than zero");
    uint256 usdcAmount = seniorPool.withdrawInFidu(amount);
    uint256 fee=usdcAmount.mul(percentageBronzeRepayment).div(100);
    repaymentFee=repaymentFee.add(fee);
  }

  function claimReward(address rewardee,uint256 amount,uint totalSupply, uint percentageFee) external override fromVault {
    uint256 amountToReward = amount.mul(getGFIBalance().sub(earningGfiFee)).div(totalSupply);
    uint256 fee=amountToReward.mul(percentageFee).div(100);
    gfiCoin.safeTransfer(rewardee,amountToReward.sub(fee));
    earningGfiFee = earningGfiFee.add(fee);
  }

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
    require(
      usdcCoin.balanceOf(address(this)) >= purchasePrice,
      "The vault does not have sufficient stable coin"
    );
    return purchasePrice;
  }

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

  function destroy() external onlyOwner {
    require(usdcCoin.balanceOf(address(this)) == 0, "Balance of stable coin must be 0");
    require(fiduCoin.balanceOf(address(this)) == 0, "Balance of Fidu coin must be 0");
    require(gfiCoin.balanceOf(address(this)) == 0, "Balance of GFI coin must be 0");
    require(poolToken.balanceOf(address(this)) == 0, "Pool token balance must be 0");

    address payable addr = payable(address(owner()));
    selfdestruct(addr);
  }

  function getGoldfinchTokenIdsOf(address owner) internal view returns (uint256[] memory) {
    uint256 count = poolToken.balanceOf(owner);
    uint256[] memory ids = new uint256[](count);
    for (uint256 i = 0; i < count; i++) {
      ids[i] = poolToken.tokenOfOwnerByIndex(owner, i);
    }
    return ids;
  }

  function migrateGoldfinchPoolTokens(address payable _toAddress, uint256 _tokenId)
    public
    onlyOwner
  {
    poolToken.safeTransferFrom(address(this), _toAddress, _tokenId);
  }

  function migrateAllGoldfinchPoolTokens(address payable _toAddress) external onlyOwner {
    uint256[] memory tokenIds = getGoldfinchTokenIdsOf(address(this));
    for (uint256 i = 0; i < tokenIds.length; i++) {
      migrateGoldfinchPoolTokens(_toAddress, tokenIds[i]);
    }
  }

  function migrateERC20(address _tokenAddress, address payable _to) external onlyOwner {
    uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
    IERC20(_tokenAddress).safeTransfer(_to, balance);
  }
}
