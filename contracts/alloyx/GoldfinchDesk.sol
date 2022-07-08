// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../goldfinch/interfaces/ITranchedPool.sol";
import "../goldfinch/interfaces/IPoolTokens.sol";
import "./interfaces/IGoldfinchDesk.sol";
import "./ConfigHelper.sol";
import "./AlloyxConfig.sol";

/**
 * @title Goldfinch Delegacy
 * @notice Middle layer to communicate with goldfinch contracts
 * @author AlloyX
 */
contract GoldfinchDesk is IGoldfinchDesk, AccessControlUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using SafeMath for uint256;

  AlloyxConfig public config;
  using ConfigHelper for AlloyxConfig;

  event PurchaseSenior(uint256 amount);
  event Mint(address _tokenReceiver, uint256 _tokenAmount);
  event Burn(address _tokenReceiver, uint256 _tokenAmount);
  event DepositDURA(address _tokenSender, uint256 _tokenAmount);
  event TransferUSDC(address _to, uint256 _amount);
  event WithdrawPoolTokens(address _withdrawer, uint256 _tokenID);
  event DepositPoolTokens(address _depositor, uint256 _tokenID);
  event PurchasePoolTokensByUSDC(uint256 _amount);
  event PurchaseFiduByUsdc(uint256 _amount);
  event Stake(address _staker, uint256 _amount);
  event SellFIDU(uint256 _amount);
  event WithdrawPoolTokenByUSDCAmount(uint256 _amount);
  event AlloyxConfigUpdated(address indexed who, address configAddress);

  mapping(uint256 => address) tokenDepositorMap;

  function initialize(address _configAddress) public initializer {
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    config = AlloyxConfig(_configAddress);
  }

  /**
   * @notice If address is whitelisted
   * @param _address The address to verify.
   */
  modifier isWhitelisted(address _address) {
    require(config.getWhitelist().isUserWhitelisted(_address), "user is not whitelisted");
    _;
  }

  function updateConfig() external onlyRole(DEFAULT_ADMIN_ROLE) {
    config = AlloyxConfig(config.configAddress());
    emit AlloyxConfigUpdated(msg.sender, address(config));
  }

  /**
   * @notice An Alloy token holder can deposit their tokens and buy FIDU
   * @param _tokenAmount Number of Alloy Tokens
   */
  function depositDuraForFidu(uint256 _tokenAmount) external isWhitelisted(msg.sender) {
    uint256 amountToWithdraw = config.getTreasury().alloyxDURAToUSDC(_tokenAmount);
    uint256 withdrawalFee = amountToWithdraw.mul(config.getPercentageDuraToFiduFee()).div(100);
    uint256 totalUsdcValueOfFidu = amountToWithdraw.sub(withdrawalFee);
    config.getDURA().burn(msg.sender, _tokenAmount);
    config.getTreasury().addDuraToFiduFee(withdrawalFee);
    config.getTreasury().transferERC20(config.usdcAddress(), address(this), totalUsdcValueOfFidu);
    uint256 fiduAmount = config.getSeniorPool().deposit(totalUsdcValueOfFidu);
    config.getFIDU().safeTransfer(msg.sender, fiduAmount);
    emit PurchaseSenior(fiduAmount);
    emit DepositDURA(msg.sender, _tokenAmount);
    emit Burn(msg.sender, _tokenAmount);
  }

  /**
   * @notice An Alloy token holder can deposit their tokens and buy back their previously deposited Pooltoken
   * @param _tokenId Pooltoken of ID
   */
  function depositDuraForPoolToken(uint256 _tokenId) external isWhitelisted(msg.sender) {
    uint256 purchaseAmount = getJuniorTokenValue(_tokenId);
    uint256 withdrawalFee = purchaseAmount.mul(config.getPercentageJuniorRedemption()).div(100);
    uint256 duraAmount = config.getTreasury().usdcToAlloyxDURA(purchaseAmount.add(withdrawalFee));
    config.getTreasury().addRedemptionFee(withdrawalFee);
    transferTokenToDepositor(msg.sender, _tokenId);
    config.getDURA().burn(msg.sender, duraAmount);
    emit Burn(msg.sender, duraAmount);
    emit DepositDURA(msg.sender, duraAmount);
    emit WithdrawPoolTokens(msg.sender, _tokenId);
  }

  /**
   * @notice A Junior token holder can deposit their NFT for dura
   * @param _tokenID NFT ID
   * @param _toStake whether to stake the dura
   */
  function depositPoolTokenForDura(uint256 _tokenID, bool _toStake)
    external
    isWhitelisted(msg.sender)
  {
    require(isValidPool(_tokenID) == true, "Not a valid pool");
    uint256 purchasePrice = getJuniorTokenValue(_tokenID);
    uint256 amountToMint = config.getTreasury().usdcToAlloyxDURA(purchasePrice);
    config.getPoolTokens().safeTransferFrom(msg.sender, config.treasuryAddress(), _tokenID);
    tokenDepositorMap[_tokenID] = msg.sender;
    if (_toStake) {
      config.getDURA().mint(address(this), amountToMint);
      config.getAlloyxStakeInfo().addStake(msg.sender, amountToMint);
      emit Mint(address(this), amountToMint);
      emit Stake(msg.sender, amountToMint);
    } else {
      config.getDURA().mint(msg.sender, amountToMint);
      emit Mint(msg.sender, amountToMint);
    }
    emit DepositPoolTokens(msg.sender, _tokenID);
  }

  /**
   * @notice A Junior token holder can deposit their NFT for stable coin
   * @param _tokenID NFT ID
   */
  function depositPoolTokensForUsdc(uint256 _tokenID) external isWhitelisted(msg.sender) {
    require(isValidPool(_tokenID) == true, "Not a valid pool");
    uint256 purchasePrice = getJuniorTokenValue(_tokenID);
    tokenDepositorMap[_tokenID] = msg.sender;
    config.getPoolTokens().safeTransferFrom(msg.sender, config.treasuryAddress(), _tokenID);
    config.getTreasury().transferERC20(config.usdcAddress(), msg.sender, purchasePrice);
    emit DepositPoolTokens(msg.sender, _tokenID);
    emit TransferUSDC(msg.sender, purchasePrice);
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
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    ITranchedPool juniorPool = ITranchedPool(_poolAddress);
    config.getTreasury().transferERC20(config.usdcAddress(), address(this), _amount);
    uint256 tokenID = juniorPool.deposit(_amount, _tranche);
    config.getPoolTokens().safeTransferFrom(address(this), config.treasuryAddress(), tokenID);
    emit PurchasePoolTokensByUSDC(_amount);
  }

  /**
   * @notice Widthdraw from junior token through delegacy to get repayments
   * @param _tokenID the ID of token to sell
   * @param _amount the amount to withdraw
   * @param _poolAddress the pool address to withdraw from
   */
  function withdrawFromJuniorToken(
    uint256 _tokenID,
    uint256 _amount,
    address _poolAddress
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    ITranchedPool juniorPool = ITranchedPool(_poolAddress);
    config.getTreasury().transferERC721(config.poolTokensAddress(), address(this), _tokenID);
    (uint256 principal, uint256 interest) = juniorPool.withdraw(_tokenID, _amount);
    uint256 fee = principal.add(interest).mul(config.getPercentageDURARepayment()).div(100);
    config.getTreasury().addRepaymentFee(fee);
    config.getPoolTokens().safeTransferFrom(address(this), config.treasuryAddress(), _tokenID);
    emit WithdrawPoolTokenByUSDCAmount(_amount);
  }

  /**
   * @notice Purchase FIDU through delegacy to get fidu inside the delegacy
   * @param _amount the amount of usdc to purchase by
   */
  function purchaseFIDU(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    config.getTreasury().transferERC20(config.usdcAddress(), address(this), _amount);
    uint256 fiduAmount = config.getSeniorPool().deposit(_amount);
    config.getFIDU().safeTransfer(config.treasuryAddress(), fiduAmount);
    emit PurchaseFiduByUsdc(_amount);
  }

  /**
   * @notice Sell senior token through delegacy to redeem fidu
   * @param _amount the amount of fidu to sell
   */
  function sellFIDU(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    config.getTreasury().transferERC20(config.fiduAddress(), address(this), _amount);
    uint256 usdcAmount = config.getSeniorPool().withdrawInFidu(_amount);
    uint256 fee = usdcAmount.mul(config.getPercentageDURARepayment()).div(100);
    config.getTreasury().addRepaymentFee(fee);
    config.getUSDC().safeTransfer(config.treasuryAddress(), usdcAmount);
    emit SellFIDU(_amount);
  }

  /**
   * @notice Using the Goldfinch contracts, read the principal, redeemed and redeemable values
   * @param _tokenID The backer NFT id
   */
  function getJuniorTokenValue(uint256 _tokenID) public view returns (uint256) {
    IPoolTokens.TokenInfo memory tokenInfo = config.getPoolTokens().getTokenInfo(_tokenID);
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
   * @notice GoldFinch PoolToken Value in Value in term of USDC
   */
  function getGoldFinchPoolTokenBalanceInUSDC() public view override returns (uint256) {
    uint256 total = 0;
    uint256 balance = config.getPoolTokens().balanceOf(config.treasuryAddress());
    for (uint256 i = 0; i < balance; i++) {
      total = total.add(
        getJuniorTokenValue(
          config.getPoolTokens().tokenOfOwnerByIndex(config.treasuryAddress(), i)
        )
      );
    }
    return total;
  }

  /**
   * @notice Send the token of the ID to address
   * @param _depositor The address to send to
   * @param _tokenId The token ID to deposit
   */
  function transferTokenToDepositor(address _depositor, uint256 _tokenId) internal {
    require(tokenDepositorMap[_tokenId] == _depositor, "The token is not deposited by this user");
    config.getTreasury().transferERC721(config.poolTokensAddress(), _depositor, _tokenId);
    delete tokenDepositorMap[_tokenId];
  }

  /**
   * @notice Using the PoolTokens interface, check if this is a valid pool
   * @param _tokenID The backer NFT id
   */
  function isValidPool(uint256 _tokenID) public view returns (bool) {
    IPoolTokens.TokenInfo memory tokenInfo = config.getPoolTokens().getTokenInfo(_tokenID);
    address tranchedPool = tokenInfo.pool;
    return config.getPoolTokens().validPool(tranchedPool);
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
    uint256 count = config.getPoolTokens().balanceOf(config.treasuryAddress());
    uint256[] memory ids = new uint256[](getTokensAvailableCountForWithdrawal(_depositor));
    uint256 index = 0;
    for (uint256 i = 0; i < count; i++) {
      uint256 id = config.getPoolTokens().tokenOfOwnerByIndex(config.treasuryAddress(), i);
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
    uint256 count = config.getPoolTokens().balanceOf(config.treasuryAddress());
    uint256 numOfTokens = 0;
    for (uint256 i = 0; i < count; i++) {
      uint256 id = config.getPoolTokens().tokenOfOwnerByIndex(config.treasuryAddress(), i);
      if (tokenDepositorMap[id] == _depositor) {
        numOfTokens += 1;
      }
    }
    return numOfTokens;
  }
}
