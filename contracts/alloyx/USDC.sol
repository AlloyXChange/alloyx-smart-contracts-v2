// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USDC is ERC20, Ownable {
    string NAME = "USDC";
    string SYMBOL = "USDC";
    uint8  DECIMALS = 6;
    constructor() ERC20("USDC", "USDC") {
    }

    function mint(address account, uint256 amount) onlyOwner external returns(bool){
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) onlyOwner external returns(bool){
        _burn(account, amount);
        return true;
    }

    function usdc() external returns(bool){
        return true;
    }

}
