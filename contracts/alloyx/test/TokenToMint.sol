// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenToMint is ERC20, Ownable {
  constructor() ERC20("TokenToMint", "TokenToMint") {}

  function mint(address account, uint256 amount) external onlyOwner returns (bool) {
    _mint(account, amount);
    return true;
  }

  function burn(address account, uint256 amount) external onlyOwner returns (bool) {
    _burn(account, amount);
    return true;
  }

  function contractName() external pure returns (string memory) {
    return "TokenToMint";
  }
}