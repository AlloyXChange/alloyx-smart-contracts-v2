// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IMintBurnableERC20.sol";

contract AlloyxTokenDURA is ERC20Upgradeable, AccessControlUpgradeable {
  function initialize() public initializer {
    __AccessControl_init();
    __ERC20_init("Duralumin", "DURA");
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function mint(address _account, uint256 _amount)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
    returns (bool)
  {
    _mint(_account, _amount);
    return true;
  }

  function burn(address _account, uint256 _amount)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
    returns (bool)
  {
    _burn(_account, _amount);
    return true;
  }

  function contractName() external pure returns (string memory) {
    return "AlloyxTokenDura";
  }
}
