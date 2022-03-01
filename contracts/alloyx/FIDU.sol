// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FIDU is ERC20, Ownable {
    function burn(address account, uint256 amount) onlyOwner external returns(bool){
        _burn(account, amount);
        return true;
    }

    function mint(address account, uint256 amount) onlyOwner external returns(bool){
        _mint(account, amount);
        return true;
    }

    function fidu() external returns(bool){
        return true;
    }

    constructor() ERC20("Fidu", "FIDU") {
    }
}
