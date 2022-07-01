// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GFI is ERC20, Ownable {
  constructor() ERC20("GFI", "GFI") {}

  function mint(address _account, uint256 _amount) external onlyOwner returns (bool) {
    _mint(_account, _amount);
    return true;
  }

  function burn(address _account, uint256 _amount) external onlyOwner returns (bool) {
    _burn(_account, _amount);
    return true;
  }

  function contractName() external returns (string memory) {
    return "GFI";
  }
}
