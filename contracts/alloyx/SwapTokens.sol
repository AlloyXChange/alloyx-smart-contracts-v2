// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IMintBurnable.sol";

contract SwapTokens is Ownable {
  using SafeMath for uint256;
  uint256 public ratio;
  uint256 public ratioDecimals;
  IMintBurnable public tokenToMint;
  IMintBurnable public tokenToBurn;
  address public existingHolder;

  constructor(
    address _tokenToMint,
    address _tokenToBurn,
    uint256 _ratio,
    uint256 _ratioDecimals,
    address _existingHolder
  ) {
    tokenToMint = IMintBurnable(_tokenToMint);
    tokenToBurn = IMintBurnable(_tokenToBurn);
    ratio = _ratio;
    ratioDecimals = _ratioDecimals;
    existingHolder = _existingHolder;
  }

  /**
   * @notice Exchange tokenToMint to tokenToBurn at exchange rate
   * @param _from the address of the token to be burned from
   * @param _tokenToBurnAmount the amount of tokenToBurn
   */
  function exchange(address _from,uint256 _tokenToBurnAmount) external onlyOwner{
    tokenToBurn.burn(_from, _tokenToBurnAmount);
    uint256 tokenToMintAmount = _tokenToBurnAmount.mul(ratio).div(10**ratioDecimals);
    tokenToMint.mint(_from, tokenToMintAmount);
  }

  /**
 * @notice Exchange all tokenToMint to tokenToBurn at exchange rate
   * @param _from the address of the token to be burned from
   * @param _tokenToBurnAmount the amount of tokenToBurn
   */
  function exchangeAll(address _from) external onlyOwner{
    uint256 tokenToBurnAmount=tokenToBurn.balanceOf(_from);
    tokenToBurn.burn(_from, tokenToBurnAmount);
    uint256 tokenToMintAmount = tokenToBurnAmount.mul(ratio).div(10**ratioDecimals);
    tokenToMint.mint(_from, tokenToMintAmount);
  }

  /**
   * @notice Exchange tokenToMint to tokenToBurn at exchange rate with existing holder
      * @param _from the address of the token to be burned from
   * @param _tokenToBurnAmount the amount of tokenToBurn
   */
  function exchangeFromExistingHolder(address _from,uint256 _tokenToBurnAmount) external onlyOwner{
    require(_from!=existingHolder,"the address from the existing holder is the same as fromAddress");
    tokenToBurn.burn(_from, _tokenToBurnAmount);
    uint256 tokenToMintAmount = _tokenToBurnAmount.mul(ratio).div(10**ratioDecimals);
    tokenToMint.mint(_from, tokenToMintAmount);
    tokenToMint.burn(existingHolder, tokenToMintAmount);
  }

  /**
   * @notice Transfer the ownership of tokenToMint contract to some other address
   * @param _to the address to transfer ownership to
   */
  function transferOwnershipOfTokenToMint(address _to) external onlyOwner {
    tokenToMint.transferOwnership(_to);
  }

  /**
   * @notice Transfer the ownership of tokenToBurn token contract to some other address
   * @param _to the address to transfer ownership to
   */
  function transferOwnershipOfTokenToBurn(address _to) external onlyOwner {
    tokenToBurn.transferOwnership(_to);
  }

  /**
   * @notice Change tokenToMint address
   * @param _tokenToMintAddress the address to change to
   */
  function changeAddressOfTokenToMint(address _tokenToMintAddress) external onlyOwner {
    tokenToMint = IMintBurnable(_tokenToMintAddress);
  }

  /**
   * @notice Change tokenToBurn address
   * @param _tokenToBurnAddress the address to change to
   */
  function changeAddressOfTokenToBurn(address _tokenToBurnAddress) external onlyOwner {
    tokenToBurn = IMintBurnable(_tokenToBurnAddress);
  }

  /**
 * @notice Change tokenToBurn address
   * @param _existingHolder the address of existing holder
   */
  function changeAddressOfExistingHolder(address _existingHolder) external onlyOwner {
    existingHolder = _existingHolder;
  }

  /**
   * @notice Change Ratio
   * @param _ratio the ratio with decimals
   */
  function setRatio(uint256 _ratio) external onlyOwner {
    ratio = _ratio;
  }

  /**
   * @notice Change Ratio Decimals
   * @param _ratioDecimals the ratio decimals
   */
  function setRatioDecimals(uint256 _ratioDecimals) external onlyOwner {
    ratioDecimals = _ratioDecimals;
  }
}
