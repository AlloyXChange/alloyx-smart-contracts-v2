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

import "../AlloyxTokenDURA.sol";
import "../IGoldfinchDelegacy.sol";

/**
 * @title AlloyX Vault
 * @notice Initial vault for AlloyX. This vault holds loan tokens generated on Goldfinch
 * and emits AlloyTokens when a liquidity provider deposits supported stable coins.
 * @author AlloyX
 */
contract AlloyxVaultV2_1 is ERC721Holder, Ownable, Pausable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  bool private vaultStarted;
  IERC20 private usdcCoin;
  AlloyxTokenDURA private alloyxTokenDURA;
  IGoldfinchDelegacy private goldfinchDelegacy;

  event DepositStable(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event DepositNFT(address _tokenAddress, address _tokenSender, uint256 _tokenID);
  event DepositAlloyx(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event PurchaseSenior(uint256 amount);
  event PurchaseJunior(uint256 amount);
  event Mint(address _tokenReceiver, uint256 _tokenAmount);
  event Burn(address _tokenReceiver, uint256 _tokenAmount);

  constructor(
    address _alloyxDURAAddress,
    address _usdcCoinAddress,
    address _goldfinchDelegacy
  ) {
    alloyxTokenDURA = AlloyxTokenDURA(_alloyxDURAAddress);
    usdcCoin = IERC20(_usdcCoinAddress);
    goldfinchDelegacy = IGoldfinchDelegacy(_goldfinchDelegacy);
    vaultStarted = false;
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
  function getAlloyxDURATokenBalanceInUSDC() public view returns (uint256) {
    return getUSDCBalance().add(goldfinchDelegacy.getGoldfinchDelegacyBalanceInUSDC());
  }

  /**
   * @notice USDC Value in Vault
   */
  function getUSDCBalance() internal view returns (uint256) {
    return usdcCoin.balanceOf(address(this));
  }

  /**
   * @notice Convert Alloyx DURA to USDC amount
   */
  function alloyxDURAToUSDC(uint256 amount) public view returns (uint256) {
    uint256 alloyDURATotalSupply = alloyxTokenDURA.totalSupply();
    uint256 totalVaultAlloyxDURAValueInUSDC = getAlloyxDURATokenBalanceInUSDC();
    return amount.mul(totalVaultAlloyxDURAValueInUSDC).div(alloyDURATotalSupply);
  }

  /**
   * @notice Convert USDC Amount to Alloyx DURA
   */
  function USDCtoAlloyxDURA(uint256 amount) public view returns (uint256) {
    uint256 alloyDURATotalSupply = alloyxTokenDURA.totalSupply();
    uint256 totalVaultAlloyxDURAValueInUSDC = getAlloyxDURATokenBalanceInUSDC();
    return amount.mul(alloyDURATotalSupply).div(totalVaultAlloyxDURAValueInUSDC);
  }

  function alloyMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(18);
  }

  function usdcMantissa() internal pure returns (uint256) {
    return uint256(10)**uint256(6);
  }

  function changeAlloyxDURAAddress(address _alloyxAddress) external onlyOwner {
    alloyxTokenDURA = AlloyxTokenDURA(_alloyxAddress);
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
   * @notice An Alloy token holder can deposit their tokens and redeem them for USDC
   * @param _tokenAmount Number of Alloy Tokens
   */
  function depositAlloyxDURATokens(uint256 _tokenAmount)
    external
    whenNotPaused
    whenVaultStarted
    returns (bool)
  {
    require(
      alloyxTokenDURA.balanceOf(msg.sender) >= _tokenAmount,
      "User has insufficient alloyx coin"
    );
    require(
      alloyxTokenDURA.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient alloyx coin"
    );
    uint256 amountToWithdraw = alloyxDURAToUSDC(_tokenAmount);
    require(amountToWithdraw > 0, "The amount of stable coin to get is not larger than 0");
    require(
      usdcCoin.balanceOf(address(this)) >= amountToWithdraw,
      "The vault does not have sufficient stable coin"
    );
    alloyxTokenDURA.burn(msg.sender, _tokenAmount);
    usdcCoin.safeTransfer(msg.sender, amountToWithdraw);
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
    returns (bool)
  {
    require(usdcCoin.balanceOf(msg.sender) >= _tokenAmount, "User has insufficient stable coin");
    require(
      usdcCoin.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient stable coin"
    );
    uint256 amountToMint = USDCtoAlloyxDURA(_tokenAmount);
    require(amountToMint > 0, "The amount of alloyx DURA coin to get is not larger than 0");
    usdcCoin.safeTransferFrom(msg.sender, address(goldfinchDelegacy), _tokenAmount);
    alloyxTokenDURA.mint(msg.sender, amountToMint);
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
    require(usdcCoin.balanceOf(address(this)) >= amount, "Vault has insufficent stable coin");
    require(amount > 0, "Must deposit more than zero");
    goldfinchDelegacy.purchaseJuniorToken(amount, poolAddress, tranche);
    emit PurchaseJunior(amount);
  }

  function purchaseSeniorTokens(uint256 amount, address poolAddress) external onlyOwner {
    require(usdcCoin.balanceOf(address(this)) >= amount, "Vault has insufficent stable coin");
    require(amount > 0, "Must deposit more than zero");
    goldfinchDelegacy.purchaseSeniorTokens(amount);
    emit PurchaseSenior(amount);
  }

  function migrateERC20(address _tokenAddress, address payable _to) external onlyOwner whenPaused {
    uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
    IERC20(_tokenAddress).safeTransfer(_to, balance);
  }

  function transferAlloyxOwnership(address _to) external onlyOwner whenPaused {
    alloyxTokenDURA.transferOwnership(_to);
  }
}
