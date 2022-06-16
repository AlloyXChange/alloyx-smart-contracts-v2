// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract AlloyxTokenDURA is ERC20Upgradeable, OwnableUpgradeable {
  function initialize() public initializer {
    __Ownable_init();
    __ERC20_init("Duralumin", "DURA");
  }

  function mint(address _account, uint256 _amount) external onlyOwner returns (bool) {
    _mint(_account, _amount);
    return true;
  }

  function burn(address _account, uint256 _amount) external onlyOwner returns (bool) {
    _burn(_account, _amount);
    return true;
  }

  function contractName() external pure returns (string memory) {
    return "AlloyxTokenDura3";
  }
}
