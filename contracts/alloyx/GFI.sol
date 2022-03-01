// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GFI is ERC20, Ownable {
    constructor() ERC20("GFI", "GFI") {
    }

    function mint(address account, uint256 amount) onlyOwner external returns(bool){
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) onlyOwner external returns(bool){
        _burn(account, amount);
        return true;
    }

    function gfi() external returns(bool){
        return true;
    }
}
