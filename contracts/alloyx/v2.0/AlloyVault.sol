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

import "../../goldfinch/interfaces/IPoolTokens.sol";
import "../../goldfinch/interfaces/ITranchedPool.sol";
import "../../goldfinch/interfaces/ISeniorPool.sol";

/**
 * @title AlloyX Vault
 * @notice Initial vault for AlloyX. This vault holds loan tokens generated on Goldfinch
 * and emits AlloyTokens when a liquidity provider deposits supported stable coins.
 * @author AlloyX
 */
contract AlloyVault is ERC721Holder, Ownable, Pausable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  bool private vaultStarted;
  IERC20 private usdcCoin;
  IERC20 private gfiCoin;
  IERC20 private fiduCoin;
  IPoolTokens private goldFinchPoolToken;
  AlloyxTokenBronze private alloyxTokenBronze;
  ISeniorPool private seniorPool;

  event DepositStable(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event DepositNFT(address _tokenAddress, address _tokenSender, uint256 _tokenID);
  event DepositAlloyx(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event PurchaseSenior(uint256 amount);
  event PurchaseJunior(uint256 amount);
  event Mint(address _tokenReceiver, uint256 _tokenAmount);
  event Burn(address _tokenReceiver, uint256 _tokenAmount);

  constructor(
    address _alloyxBronzeAddress,
    address _usdcCoinAddress,
    address _fiduCoinAddress,
    address _gfiCoinAddress,
    address _goldFinchTokenAddress,
    address _seniorPoolAddress
  ) {
    alloyxTokenBronze = AlloyxTokenBronze(_alloyxBronzeAddress);
    usdcCoin = IERC20(_usdcCoinAddress);
    gfiCoin = IERC20(_gfiCoinAddress);
    fiduCoin = IERC20(_fiduCoinAddress);
    goldFinchPoolToken = IPoolTokens(_goldFinchTokenAddress);
    seniorPool = ISeniorPool(_seniorPoolAddress);
    vaultStarted = false;
  }

  /**
   * @notice Alloy Brown Token Value in terms of USDC
   */
  function getAlloyxBronzeTokenBalanceInUSDC() internal view returns (uint256) {
    return getFiduBalanceInUSDC().add(getUSDCBalance()).add(getGoldFinchPoolTokenBalanceInUSDC());
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
  function getUSDCBalance() internal view returns (uint256) {
    return usdcCoin.balanceOf(address(this));
  }

  /**
   * @notice GFI Balance in Vault
   */
  function getGFIBalance() internal view returns (uint256) {
    return gfiCoin.balanceOf(address(this));
  }

  /**
   * @notice GoldFinch PoolToken Value in Value in term of USDC
   */
  function getGoldFinchPoolTokenBalanceInUSDC() internal view returns (uint256) {
    uint256 total = 0;
    uint256 balance = goldFinchPoolToken.balanceOf(address(this));
    for (uint256 i = 0; i < balance; i++) {
      total = total.add(
        getJuniorTokenValue(
          address(goldFinchPoolToken),
          goldFinchPoolToken.tokenOfOwnerByIndex(address(this), i)
        )
      );
    }
    return total.mul(usdcMantissa());
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
  function USDCtoAlloyxBronze(uint256 amount) public view returns (uint256) {
    uint256 alloyBronzeTotalSupply = alloyxTokenBronze.totalSupply();
    uint256 totalVaultAlloyxBronzeValueInUSDC = getAlloyxBronzeTokenBalanceInUSDC();
    return amount.mul(alloyBronzeTotalSupply).div(totalVaultAlloyxBronzeValueInUSDC);
  }

  function fiduToUSDC(uint256 amount) internal pure returns (uint256) {
    return amount.div(fiduMantissa().div(usdcMantissa()));
  }

  function fiduMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(18);
  }

  function alloyMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(18);
  }

  function usdcMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(6);
  }

  function changeAlloyxBronzeAddress(address _alloyxAddress) external onlyOwner {
    alloyxTokenBronze = AlloyxTokenBronze(_alloyxAddress);
  }

  function changeSeniorPoolAddress(address _seniorPool) external onlyOwner {
    seniorPool = ISeniorPool(_seniorPool);
  }

  function changePoolTokenAddress(address _poolToken) external onlyOwner {
    goldFinchPoolToken = IPoolTokens(_poolToken);
  }

  modifier whenVaultStarted() {
    require(vaultStarted, "Vault has not start accepting deposits");
    _;
  }

  modifier whenVaultNotStarted() {
    require(!vaultStarted, "Vault has already start accepting deposits");
    _;
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
    require(amountToWithdraw > 0, "The amount of stable coin to get is not larger than 0");
    require(
      usdcCoin.balanceOf(address(this)) >= amountToWithdraw,
      "The vault does not have sufficient stable coin"
    );
    alloyxTokenBronze.burn(msg.sender, _tokenAmount);
    usdcCoin.safeTransfer(msg.sender, amountToWithdraw);
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
    uint256 amountToMint = USDCtoAlloyxBronze(_tokenAmount);
    require(amountToMint > 0, "The amount of alloyx bronze coin to get is not larger than 0");
    usdcCoin.safeTransferFrom(msg.sender, address(this), _tokenAmount);
    alloyxTokenBronze.mint(msg.sender, amountToMint);
    emit DepositStable(address(usdcCoin), msg.sender, amountToMint);
    emit Mint(msg.sender, amountToMint);
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
    require(_tokenAddress == address(goldFinchPoolToken), "Not Goldfinch Pool Token");
    require(isValidPool(_tokenAddress, _tokenID) == true, "Not a valid pool");
    require(IERC721(_tokenAddress).ownerOf(_tokenID) == msg.sender, "User does not own this token");
    require(
      IERC721(_tokenAddress).getApproved(_tokenID) == address(this),
      "User has not approved the vault for this token"
    );
    uint256 purchasePrice = getJuniorTokenValue(_tokenAddress, _tokenID);
    require(purchasePrice > 0, "The amount of stable coin to get is not larger than 0");
    require(
      usdcCoin.balanceOf(address(this)) >= purchasePrice,
      "The vault does not have sufficient stable coin"
    );
    IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenID);
    usdcCoin.safeTransfer(msg.sender, purchasePrice);
    emit DepositNFT(_tokenAddress, msg.sender, _tokenID);
    return true;
  }

  function destroy() external onlyOwner whenPaused {
    require(usdcCoin.balanceOf(address(this)) == 0, "Balance of stable coin must be 0");
    require(fiduCoin.balanceOf(address(this)) == 0, "Balance of Fidu coin must be 0");
    require(gfiCoin.balanceOf(address(this)) == 0, "Balance of GFI coin must be 0");

    address payable addr = payable(address(owner()));
    selfdestruct(addr);
  }

  /**
   * @notice Using the PoolTokens interface, check if this is a valid pool
   * @param _tokenAddress The backer NFT address
   * @param _tokenID The backer NFT id
   */
  function isValidPool(address _tokenAddress, uint256 _tokenID) public view returns (bool) {
    IPoolTokens poolTokenContract = IPoolTokens(_tokenAddress);
    IPoolTokens.TokenInfo memory tokenInfo = poolTokenContract.getTokenInfo(_tokenID);
    address tranchedPool = tokenInfo.pool;
    return poolTokenContract.validPool(tranchedPool);
  }

  /**
   * @notice Using the Goldfinch contracts, read the principal, redeemed and redeemable values
   * @param _tokenAddress The backer NFT address
   * @param _tokenID The backer NFT id
   */
  function getJuniorTokenValue(address _tokenAddress, uint256 _tokenID)
    public
    view
    returns (uint256)
  {
    // first get the amount redeemed and the principal
    IPoolTokens poolTokenContract = IPoolTokens(_tokenAddress);
    IPoolTokens.TokenInfo memory tokenInfo = poolTokenContract.getTokenInfo(_tokenID);
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
    return principalAmount.sub(totalRedeemed).add(totalRedeemable).mul(usdcMantissa());
  }

  function purchaseJuniorToken(
    uint256 amount,
    address poolAddress,
    uint256 tranche
  ) external onlyOwner {
    require(usdcCoin.balanceOf(address(this)) >= amount, "Vault has insufficent stable coin");
    require(amount > 0, "Must deposit more than zero");
    ITranchedPool juniorPool = ITranchedPool(poolAddress);
    juniorPool.deposit(amount, tranche);
    emit PurchaseJunior(amount);
  }

  function purchaseSeniorTokens(uint256 amount, address poolAddress) external onlyOwner {
    require(usdcCoin.balanceOf(address(this)) >= amount, "Vault has insufficent stable coin");
    require(amount > 0, "Must deposit more than zero");
    ISeniorPool seniorPoolInterface = ISeniorPool(poolAddress);
    seniorPoolInterface.deposit(amount);
    emit PurchaseSenior(amount);
  }

  function migrateGoldfinchPoolTokens(address payable _toAddress, uint256 _tokenId)
    public
    onlyOwner
    whenPaused
  {
    goldFinchPoolToken.safeTransferFrom(address(this), _toAddress, _tokenId);
  }

  function getGoldfinchTokenIdsOf(address owner) internal view returns (uint256[] memory) {
    uint256 count = goldFinchPoolToken.balanceOf(owner);
    uint256[] memory ids = new uint256[](count);
    for (uint256 i = 0; i < count; i++) {
      ids[i] = goldFinchPoolToken.tokenOfOwnerByIndex(owner, i);
    }
    return ids;
  }

  function migrateAllGoldfinchPoolTokens(address payable _toAddress)
    external
    onlyOwner
    whenPaused
  {
    uint256[] memory tokenIds = getGoldfinchTokenIdsOf(address(this));
    for (uint256 i = 0; i < tokenIds.length; i++) {
      migrateGoldfinchPoolTokens(_toAddress, tokenIds[i]);
    }
  }

  function migrateERC20(address _tokenAddress, address payable _to) public onlyOwner whenPaused {
    uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
    IERC20(_tokenAddress).safeTransfer(_to, balance);
  }

  function transferAlloyxOwnership(address _to) external onlyOwner whenPaused {
    alloyxTokenBronze.transferOwnership(_to);
  }
}
