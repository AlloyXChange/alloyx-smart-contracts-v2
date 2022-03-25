// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FIDU is ERC20, Ownable {
    constructor() ERC20("FIDU", "FIDU") {}

    function mint(address account, uint256 amount) external onlyOwner returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) external onlyOwner returns (bool) {
        _burn(account, amount);
        return true;
    }

    function fidu() external returns (bool) {
        return true;
    }
}
