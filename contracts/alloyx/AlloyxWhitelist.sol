// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/IAlloyxWhitelist.sol";

/**
 * @title AlloyxWhitelist
 * @author AlloyX
 */
contract AlloyxWhitelist is Ownable, IAlloyxWhitelist {
  mapping(address => bool) whitelistedAddresses;
  IERC1155 private uidToken;
  event ChangeAddress(string _field, address _address);

  constructor(address _uidAddress) public {
    uidToken = IERC1155(_uidAddress);
  }

  /**
   * @notice If address is whitelisted
   * @param _address The address to verify.
   */
  modifier isWhitelisted(address _address) {
    require(isUserWhitelisted(_address), "You need to be whitelisted");
    _;
  }

  /**
   * @notice If address is not whitelisted
   * @param _address The address to verify.
   */
  modifier notWhitelisted(address _address) {
    require(!isUserWhitelisted(_address), "You are whitelisted");
    _;
  }

  /**
   * @notice If address is not whitelisted by goldfinch(non-US entity or non-US individual)
   * @param _userAddress The address to verify.
   */
  function hasWhitelistedUID(address _userAddress) public view returns (bool) {
    uint256 balanceForNonUsIndividual = uidToken.balanceOf(_userAddress, 0);
    uint256 balanceForNonUsEntity = uidToken.balanceOf(_userAddress, 4);
    return balanceForNonUsIndividual + balanceForNonUsEntity > 0;
  }

  /**
   * @notice Add whitelist address
   * @param _addressToWhitelist The address to whitelist.
   */
  function addWhitelistedUser(address _addressToWhitelist)
    public
    onlyOwner
    notWhitelisted(_addressToWhitelist)
  {
    whitelistedAddresses[_addressToWhitelist] = true;
  }

  /**
   * @notice Remove whitelist address
   * @param _addressToDeWhitelist The address to de-whitelist.
   */
  function removeWhitelistedUser(address _addressToDeWhitelist)
    public
    onlyOwner
    isWhitelisted(_addressToDeWhitelist)
  {
    whitelistedAddresses[_addressToDeWhitelist] = false;
  }

  /**
   * @notice Check whether user is whitelisted
   * @param _whitelistedAddress The address to whitelist.
   */
  function isUserWhitelisted(address _whitelistedAddress) public view override returns (bool) {
    return whitelistedAddresses[_whitelistedAddress] || hasWhitelistedUID(_whitelistedAddress);
  }

  /**
   * @notice Change UID address
   * @param _uidAddress the address to change to
   */
  function changeUIDAddress(address _uidAddress) external onlyOwner {
    uidToken = IERC1155(_uidAddress);
    emit ChangeAddress("uidToken", _uidAddress);
  }
}
