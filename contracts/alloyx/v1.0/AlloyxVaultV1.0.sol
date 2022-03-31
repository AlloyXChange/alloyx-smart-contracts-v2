// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../AlloyxTokenBronze.sol";

import "../../goldfinch/interfaces/IPoolTokens.sol";
import "../../goldfinch/interfaces/ITranchedPool.sol";

/**
 * @title AlloyX Vault
 * @notice Initial vault for AlloyX. This vault holds loan tokens generated on Goldfinch
 * and emits AlloyTokens when a liquidity provider deposits supported stable coins. The contract
 * uses a pricing oracle to determine the value of the underlying assets
 * @author AlloyX
 */
contract AlloyxVaultV1_0 is ERC721Holder, ChainlinkClient, Ownable, Pausable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  using Chainlink for Chainlink.Request;
  enum Type {
    Mint,
    Burn
  }
  struct TokenMeta {
    address receiver;
    uint256 amountOrId;
    address fromToken;
    address toToken;
  }
  // Request ID => Tokens to Process
  mapping(bytes32 => TokenMeta) tokenToProcessMap;

  uint256 private result;
  address private oracle;
  bytes32 private jobId;
  uint256 private fee;
  IERC20 private stableCoin;
  IERC20 private gfiCoin;
  IERC20 private fiduCoin;
  AlloyxTokenBronze private alloyToken;

  event DepositStable(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event DepositNFT(address _tokenAddress, address _tokenSender, uint256 _tokenID);
  event DepositAlloyx(address _tokenAddress, address _tokenSender, uint256 _tokenAmount);
  event Mint(address _tokenReceiver, uint256 _tokenAmount);
  event Burn(address _tokenReceiver, uint256 _tokenAmount);

  /**
   * Network: Kovan
   * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel
   * Node)
   * Job ID: d5270d1c311941d0b08bead21fea7747
   * Fee: 0.1 LINK
   */
  constructor(
    address _alloyxAddress,
    address _stableCoinAddress,
    address _fiduCoinAddress,
    address _gfiCoinAddress
  ) {
    setPublicChainlinkToken();
    oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
    jobId = "d5270d1c311941d0b08bead21fea7747";
    fee = 0.1 * 10**18;

    alloyToken = AlloyxTokenBronze(_alloyxAddress);
    stableCoin = IERC20(_stableCoinAddress);
    gfiCoin = IERC20(_gfiCoinAddress);
    fiduCoin = IERC20(_fiduCoinAddress);
  }

  /**
   * @notice The pricing oracle that gets stable coin exchange rate for the Alloy token
   */
  function requestAlloyUSDCExchangeRate() public returns (bytes32 requestId) {
    Chainlink.Request memory request = buildChainlinkRequest(
      jobId,
      address(this),
      this.fulfill.selector
    );
    request.add("get", "https://alloyxbackend.uw.r.appspot.com/amountToMint");
    return sendChainlinkRequestTo(oracle, request, fee);
  }

  /**
   * @notice The response we get from the Chainlink request
   * @param _requestId Unique identifier for the request
   * @param _result The API response
   */
  function fulfill(bytes32 _requestId, uint256 _result)
    public
    recordChainlinkFulfillment(_requestId)
  {
    uint256 tokenAmountOrId = tokenToProcessMap[_requestId].amountOrId;
    address receiver = tokenToProcessMap[_requestId].receiver;
    address fromToken = tokenToProcessMap[_requestId].fromToken;
    address toToken = tokenToProcessMap[_requestId].toToken;
    if (fromToken == address(stableCoin) && toToken == address(alloyToken)) {
      uint256 amountToMint = (_result.mul(tokenAmountOrId)).div((10**8));
      require(amountToMint > 0, "The amount of alloyx coin to get is not larger than 0");
      stableCoin.safeTransferFrom(receiver, address(this), tokenAmountOrId);
      alloyToken.mint(receiver, amountToMint);
      delete tokenToProcessMap[_requestId];
      emit DepositStable(fromToken, receiver, tokenAmountOrId);
      emit Mint(receiver, amountToMint);
    }
    if (fromToken == address(alloyToken) && toToken == address(stableCoin)) {
      uint256 amountToWithdraw = (tokenAmountOrId.mul((10**8))) / _result;
      require(amountToWithdraw > 0, "The amount of stable coin to get is not larger than 0");
      require(
        stableCoin.balanceOf(address(this)) >= amountToWithdraw,
        "The vault does not have sufficient stable coin"
      );
      alloyToken.burn(receiver, tokenAmountOrId);
      stableCoin.safeTransfer(receiver, amountToWithdraw);
      delete tokenToProcessMap[_requestId];
      emit DepositAlloyx(fromToken, receiver, tokenAmountOrId);
      emit Burn(receiver, tokenAmountOrId);
    }
  }

  function changeAlloyxAddress(address _alloyxAddress) external onlyOwner {
    alloyToken = AlloyxTokenBronze(_alloyxAddress);
  }

  function pause() external onlyOwner whenNotPaused {
    _pause();
  }

  function unpause() external onlyOwner whenPaused {
    _unpause();
  }

  function balanceOfToken(address _tokenAddress) external view returns (uint256) {
    return IERC20(_tokenAddress).balanceOf(address(this));
  }

  /**
   * @notice An Alloy token holder can deposit their tokens and redeem them for USDC
   * @param _tokenAmount Number of Alloy Tokens
   */
  function depositAlloyTokens(uint256 _tokenAmount) external whenNotPaused returns (bool) {
    require(alloyToken.balanceOf(msg.sender) >= _tokenAmount, "User has insufficient alloyx coin");
    require(
      alloyToken.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient alloyx coin"
    );
    bytes32 requestId = requestAlloyUSDCExchangeRate();
    tokenToProcessMap[requestId] = TokenMeta(
      msg.sender,
      _tokenAmount,
      address(alloyToken),
      address(stableCoin)
    );
    return true;
  }

  /**
   * @notice A Liquidity Provider can deposit supported stable coins for Alloy Tokens
   * @param _tokenAmount Number of stable coin
   */
  function depositStableCoin(uint256 _tokenAmount) external whenNotPaused returns (bool) {
    require(stableCoin.balanceOf(msg.sender) >= _tokenAmount, "User has insufficient stable coin");
    require(
      stableCoin.allowance(msg.sender, address(this)) >= _tokenAmount,
      "User has not approved the vault for sufficient stable coin"
    );
    bytes32 requestId = requestAlloyUSDCExchangeRate();
    tokenToProcessMap[requestId] = TokenMeta(
      msg.sender,
      _tokenAmount,
      address(stableCoin),
      address(alloyToken)
    );
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
    returns (bool)
  {
    require(isValidPool(_tokenAddress, _tokenID) == true, "Not a valid pool");
    require(IERC721(_tokenAddress).ownerOf(_tokenID) == msg.sender, "User does not own this token");
    require(
      IERC721(_tokenAddress).getApproved(_tokenID) == address(this),
      "User has not approved the vault for this token"
    );
    uint256 purchasePrice = getJuniorTokenValue(_tokenAddress, _tokenID);
    require(purchasePrice > 0, "The amount of stable coin to get is not larger than 0");
    require(
      stableCoin.balanceOf(address(this)) >= purchasePrice,
      "The vault does not have sufficient stable coin"
    );
    IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenID);
    stableCoin.safeTransfer(msg.sender, purchasePrice);
    emit DepositNFT(_tokenAddress, msg.sender, _tokenID);
    return true;
  }

  function destroy() external onlyOwner whenPaused {
    require(stableCoin.balanceOf(address(this)) == 0, "Balance of stable coin must be 0");
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
    return principalAmount.sub(totalRedeemed).add(totalRedeemable);
  }

  function migrateNFT(
    address _tokenAddress,
    address payable _toAddress,
    uint256 _tokenID
  ) external onlyOwner whenPaused {
    IERC721(_tokenAddress).safeTransferFrom(address(this), _toAddress, _tokenID);
  }

  function migrateERC20(address _tokenAddress, address payable _to) external onlyOwner whenPaused {
    uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
    IERC20(_tokenAddress).safeTransfer(_to, balance);
  }

  function transferAlloyxOwnership(address _to) external onlyOwner whenPaused {
    alloyToken.transferOwnership(_to);
  }
}
