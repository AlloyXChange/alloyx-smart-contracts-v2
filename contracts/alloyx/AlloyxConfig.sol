// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ConfigOptions.sol";
import "./interfaces/IAlloyxConfig.sol";

/**
 * @title AlloyX Configuration
 * @author AlloyX
 */

contract AlloyxConfig is AccessControlUpgradeable {
  mapping(uint256 => address) public addresses;
  mapping(uint256 => uint256) public numbers;

  event AddressUpdated(address owner, uint256 index, address oldValue, address newValue);
  event NumberUpdated(address owner, uint256 index, uint256 oldValue, uint256 newValue);

  function initialize() public initializer {
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function setAddress(uint256 addressIndex, address newAddress)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(addresses[addressIndex] == address(0), "Address has already been initialized");

    emit AddressUpdated(msg.sender, addressIndex, addresses[addressIndex], newAddress);
    addresses[addressIndex] = newAddress;
  }

  function setNumber(uint256 index, uint256 newNumber) public onlyRole(DEFAULT_ADMIN_ROLE) {
    emit NumberUpdated(msg.sender, index, numbers[index], newNumber);
    numbers[index] = newNumber;
  }

  function copyFromOtherConfig(
    address _initialConfig,
    uint256 numbersLength,
    uint256 addressesLength
  ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    IAlloyxConfig initialConfig = IAlloyxConfig(_initialConfig);
    for (uint256 i = 0; i < numbersLength; i++) {
      setNumber(i, initialConfig.getNumber(i));
    }

    for (uint256 i = 0; i < addressesLength; i++) {
      if (getAddress(i) == address(0)) {
        setAddress(i, initialConfig.getAddress(i));
      }
    }
  }

  /*
    Using custom getters in case we want to change underlying implementation later,
    or add checks or validations later on.
  */
  function getAddress(uint256 index) public view returns (address) {
    return addresses[index];
  }

  function getNumber(uint256 index) public view returns (uint256) {
    return numbers[index];
  }
}
