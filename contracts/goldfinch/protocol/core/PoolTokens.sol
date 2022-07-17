// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../interfaces/ITranchedPool.sol";
import "../../interfaces/IPoolTokens.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title PoolTokens
 * @notice PoolTokens is an ERC721 compliant contract, which can represent
 *  junior tranche or senior tranche shares of any of the borrower pools.
 * @author Goldfinch
 */

contract PoolTokens is ERC721Enumerable, IPoolTokens {
  struct PoolInfo {
    uint256 totalMinted;
    uint256 totalPrincipalRedeemed;
    bool created;
  }

  uint256 lastTokenId = 0;

  // tokenId => tokenInfo
  mapping(uint256 => TokenInfo) public tokens;
  // poolAddress => poolInfo
  mapping(address => PoolInfo) public pools;

  address poolAddress;

  constructor(address _poolAddress) ERC721("PoolTokens", "PTN") {
    poolAddress = _poolAddress;
  }

  /**
   * @notice Called by pool to create a debt position in a particular tranche and amount
   * @param params Struct containing the tranche and the amount
   * @param to The address that should own the position
   * @return tokenId The token ID (auto-incrementing integer across all pools)
   */
  function mint(MintParams calldata params, address to)
    external
    override
    returns (uint256 tokenId)
  {
    return self_mint(params, to, lastTokenId + 1);
  }

  function self_mint(
    MintParams calldata params,
    address to,
    uint256 tokenId
  ) public returns (uint256 tokenIdReturn) {
    tokenId = createToken(params, poolAddress, tokenId);
    _mint(to, tokenId);
    lastTokenId = tokenId;
    return tokenId;
  }

  /**
   * @notice Updates a token to reflect the principal and interest amounts that have been redeemed.
   * @param tokenId The token id to update (must be owned by the pool calling this function)
   * @param principalRedeemed The incremental amount of principal redeemed (cannot be more than principal deposited)
   * @param interestRedeemed The incremental amount of interest redeemed
   */
  function redeem(
    uint256 tokenId,
    uint256 principalRedeemed,
    uint256 interestRedeemed
  ) external override {}

  /**
   * @dev Burns a specific ERC721 token, and removes the data from our mappings
   * @param tokenId uint256 id of the ERC721 token to be burned.
   */
  function burn(uint256 tokenId) external virtual override {}

  function getTokenInfo(uint256 tokenId) external view virtual override returns (TokenInfo memory) {
    return tokens[tokenId];
  }

  function setPoolAddress(address _poolAddress) external {
    poolAddress = _poolAddress;
  }

  /**
   * @notice Called by the GoldfinchFactory to register the pool as a valid pool. Only valid pools can mint/redeem
   * tokens
   * @param newPool The address of the newly created pool
   */
  function onPoolCreated(address newPool) external override {
    pools[newPool].created = true;
  }

  /**
   * @notice Returns a boolean representing whether the spender is the owner or the approved spender of the token
   * @param spender The address to check
   * @param tokenId The token id to check for
   * @return True if approved to redeem/transfer/burn the token, false if not
   */
  function isApprovedOrOwner(address spender, uint256 tokenId)
    external
    view
    override
    returns (bool)
  {
    return _isApprovedOrOwner(spender, tokenId);
  }

  function validPool(address sender) public view virtual override returns (bool) {
    return true;
  }

  function createToken(
    MintParams calldata params,
    address _poolAddress,
    uint256 tokenId
  ) internal returns (uint256 tokenIdReturn) {
    tokens[tokenId] = TokenInfo({
      pool: _poolAddress,
      tranche: params.tranche,
      principalAmount: params.principalAmount,
      principalRedeemed: 0,
      interestRedeemed: 0
    });
    return tokenId;
  }

  function _getTokenInfo(uint256 tokenId) internal view returns (TokenInfo memory) {
    return tokens[tokenId];
  }
}
