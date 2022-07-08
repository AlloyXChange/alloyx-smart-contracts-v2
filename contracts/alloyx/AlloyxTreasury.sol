// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./interfaces/IAlloyxTreasury.sol";
import "./ConfigHelper.sol";
import "./AlloyxConfig.sol";

/**
 * @title AlloyX Vault
 * @notice Initial vault for AlloyX. This vault holds loan tokens generated on Goldfinch
 * and emits AlloyTokens when a liquidity provider deposits supported stable coins.
 * @author AlloyX
 */
contract AlloyxTreasury is IAlloyxTreasury,ERC721HolderUpgradeable, AccessControlUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using SafeMath for uint256;

  AlloyxConfig public config;
  using ConfigHelper for AlloyxConfig;

  uint256 public earningGfiFee;
  uint256 public repaymentFee;
  uint256 public redemptionFee;
  uint256 public duraToFiduFee;

  event AlloyxConfigUpdated(address indexed who, address configAddress);

  function initialize(address _configAddress) public initializer {
    __ERC721Holder_init();
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function getEarningGfiFee() external view override returns (uint256){
    return earningGfiFee;
  }

  function updateConfig() external onlyRole(DEFAULT_ADMIN_ROLE) {
    config = AlloyxConfig(config.configAddress());
    emit AlloyxConfigUpdated(msg.sender, address(config));
  }

  function addEarningGfiFee(uint256 _amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    earningGfiFee += _amount;
  }

  function addRepaymentFee(uint256 _amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    repaymentFee += _amount;
  }

  function addRedemptionFee(uint256 _amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    redemptionFee += _amount;
  }

  function addDuraToFiduFee(uint256 _amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    duraToFiduFee += _amount;
  }

  /**
   * @notice Alloy DURA Token Value in terms of USDC
   */
  function getTreasuryTotalBalanceInUSDC() public view override returns (uint256) {
    uint256 totalValue = config
      .getUSDC()
      .balanceOf(address(this))
      .add(getFiduBalanceInUSDC())
      .add(config.getGoldfinchDesk().getGoldFinchPoolTokenBalanceInUSDC());
    uint256 entireFee = redemptionFee.add(duraToFiduFee).add(repaymentFee);
    return totalValue.sub(entireFee);
  }

  /**
   * @notice Convert Alloyx DURA to USDC amount
   * @param _amount the amount of DURA token to convert to usdc
   */
  function alloyxDURAToUSDC(uint256 _amount) public view override returns (uint256) {
    uint256 alloyDURATotalSupply = config.getDURA().totalSupply();
    uint256 totalValue = getTreasuryTotalBalanceInUSDC();
    return _amount.mul(totalValue).div(alloyDURATotalSupply);
  }

  /**
   * @notice Convert USDC Amount to Alloyx DURA
   * @param _amount the amount of usdc to convert to DURA token
   */
  function usdcToAlloyxDURA(uint256 _amount) public view override returns (uint256) {
    uint256 alloyDURATotalSupply = config.getDURA().totalSupply();
    uint256 totalValue = getTreasuryTotalBalanceInUSDC();
    return _amount.mul(alloyDURATotalSupply).div(totalValue);
  }

  /**
   * @notice Fidu Value in Vault in term of USDC
   */
  function getFiduBalanceInUSDC() internal view returns (uint256) {
    return
      fiduToUSDC(
        config.getFIDU().balanceOf(address(this)).mul(config.getSeniorPool().sharePrice()).div(
          fiduMantissa()
        )
      );
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
   * @notice Transfer certain amount token of certain address to some other account
   * @param _account the address to transfer
   * @param _amount the amount to transfer
   * @param _tokenAddress the token address to transfer
   */
  function transferERC20(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    IERC20Upgradeable(_tokenAddress).safeTransfer(_account, _amount);
  }

  /**
   * @notice Transfer certain amount token of certain address to some other account
   * @param _account the address to transfer
   * @param _tokenId the token ID to transfer
   * @param _tokenAddress the token address to transfer
   */
  function transferERC721(
    address _tokenAddress,
    address _account,
    uint256 _tokenId
  ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    IERC721(_tokenAddress).safeTransferFrom(address(this), _account, _tokenId);
  }

  /**
   * @notice Approve certain amount token of certain address to some other account
   * @param _account the address to approve
   * @param _amount the amount to approve
   * @param _tokenAddress the token address to approve
   */
  function approveERC20(
    address _tokenAddress,
    address _account,
    uint256 _amount
  ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    IERC20Upgradeable(_tokenAddress).approve(_account, _amount);
  }

  /**
   * @notice Approve certain amount token of certain address to some other account
   * @param _account the address to approve
   * @param _tokenId the token ID to transfer
   * @param _tokenAddress the token address to approve
   */
  function approveERC721(
    address _tokenAddress,
    address _account,
    uint256 _tokenId
  ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    IERC721(_tokenAddress).approve(_account, _tokenId);
  }

  /**
   * @notice Migrate certain ERC20 to an address
   * @param _tokenAddress the token address to migrate
   * @param _to the address to transfer tokens to
   */
  function migrateERC20(address _tokenAddress, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 balance = IERC20Upgradeable(_tokenAddress).balanceOf(address(this));
    IERC20Upgradeable(_tokenAddress).safeTransfer(_to, balance);
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
  ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    IERC721(_tokenAddress).safeTransferFrom(address(this), _toAddress, _tokenId);
  }

  /**
   * @notice Migrate all Pooltokens to an address
   * @param _tokenAddress the address of the ERC721Enumerable
   * @param _toAddress the address to transfer tokens to
   */
  function migrateAllERC721Enumerable(address _tokenAddress, address _toAddress)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    uint256[] memory tokenIds = getERC721EnumerableIdsOf(_toAddress, address(this));
    for (uint256 i = 0; i < tokenIds.length; i++) {
      migrateERC721(_tokenAddress, _toAddress, tokenIds[i]);
    }
  }

  /**
   * @notice Get the IDs of Pooltokens of an addresss
   * @param _tokenAddress the address of the ERC721Enumerable
   * @param _owner the address to get IDs of
   */
  function getERC721EnumerableIdsOf(address _tokenAddress, address _owner)
    internal
    view
    returns (uint256[] memory)
  {
    uint256 count = IERC721Enumerable(_tokenAddress).balanceOf(_owner);
    uint256[] memory ids = new uint256[](count);
    for (uint256 i = 0; i < count; i++) {
      ids[i] = IERC721Enumerable(_tokenAddress).tokenOfOwnerByIndex(_owner, i);
    }
    return ids;
  }
}
