// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title Mintable + Burnable
 * @author AlloyX
 */
interface IMintBurnable {
  function mint(address _account, uint256 _amount) external returns (bool);

  function burn(address _account, uint256 _amount) external returns (bool);

  function transferOwnership(address _to) external;

  function balanceOf(address account) external view returns (uint256);
}
