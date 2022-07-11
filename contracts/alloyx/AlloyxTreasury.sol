// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./interfaces/IAlloyxTreasury.sol";
import "./ConfigHelper.sol";
import "./AlloyxConfig.sol";
import "./AdminUpgradeable.sol";

/**
 * @title AlloyX Vault
 * @notice Initial vault for AlloyX. This vault holds loan tokens generated on Goldfinch
 * and emits AlloyTokens when a liquidity provider deposits supported stable coins.
 * @author AlloyX
 */
contract AlloyxTreasury is IAlloyxTreasury, ERC721HolderUpgradeable, AdminUpgradeable {
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
    __AdminUpgradeable_init(msg.sender);
    config = AlloyxConfig(_configAddress);
  }

  function updateConfig() external onlyAdmin {
    config = AlloyxConfig(config.configAddress());
    emit AlloyxConfigUpdated(msg.sender, address(config));
  }

  function getAllUsdcFees() public view override returns (uint256) {
    return repaymentFee.add(redemptionFee).add(duraToFiduFee);
  }

  function getEarningGfiFee() external view override returns (uint256) {
    return earningGfiFee;
  }

  function getRepaymentFee() external view override returns (uint256) {
    return repaymentFee;
  }

  function getRedemptionFee() external view override returns (uint256) {
    return redemptionFee;
  }

  function getDuraToFiduFee() external view override returns (uint256) {
    return duraToFiduFee;
  }

  function addEarningGfiFee(uint256 _amount) external override onlyAdmin {
    earningGfiFee += _amount;
  }

  function addRepaymentFee(uint256 _amount) external override onlyAdmin {
    repaymentFee += _amount;
  }

  function addRedemptionFee(uint256 _amount) external override onlyAdmin {
    redemptionFee += _amount;
  }

  function addDuraToFiduFee(uint256 _amount) external override onlyAdmin {
    duraToFiduFee += _amount;
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
  ) public override onlyAdmin {
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
  ) public override onlyAdmin {
    IERC721(_tokenAddress).safeTransferFrom(address(this), _account, _tokenId);
  }

  /**
   * @notice USDC fees including repaymentFee,redemptionFee,duraToFiduFee
   * @param _to the address to transfer tokens to
   */
  function transferAllUsdcFees(address _to) external onlyAdmin {
    transferERC20(config.usdcAddress(), _to, getAllUsdcFees());
  }

  /**
   * @notice Gfi fees including earningGfiFee
   * @param _to the address to transfer tokens to
   */
  function transferAllGfiFees(address _to) external onlyAdmin {
    transferERC20(config.gfiAddress(), _to, earningGfiFee);
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
  ) external override onlyAdmin {
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
  ) external override onlyAdmin {
    IERC721(_tokenAddress).approve(_account, _tokenId);
  }

  /**
   * @notice Migrate certain ERC20 to an address
   * @param _tokenAddress the token address to migrate
   * @param _to the address to transfer tokens to
   */
  function migrateERC20(address _tokenAddress, address _to) external onlyAdmin {
    uint256 balance = IERC20Upgradeable(_tokenAddress).balanceOf(address(this));
    IERC20Upgradeable(_tokenAddress).safeTransfer(_to, balance);
  }

  /**
   * @notice Migrate all Pooltokens to an address
   * @param _tokenAddress the address of the ERC721Enumerable
   * @param _toAddress the address to transfer tokens to
   */
  function migrateAllERC721Enumerable(address _tokenAddress, address _toAddress)
    external
    onlyAdmin
  {
    uint256[] memory tokenIds = getERC721EnumerableIdsOf(_tokenAddress, address(this));
    for (uint256 i = 0; i < tokenIds.length; i++) {
      transferERC721(_tokenAddress, _toAddress, tokenIds[i]);
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
