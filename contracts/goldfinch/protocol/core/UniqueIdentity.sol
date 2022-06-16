// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/**
 * @title UniqueIdentity
 * @notice UniqueIdentity is an ERC1155-compliant contract for representing
 * the identity verification status of addresses.
 * @author Goldfinch
 */

contract UniqueIdentity is ERC1155 {
  bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

  uint256 public constant ID_TYPE_0 = 0;
  uint256 public constant ID_TYPE_1 = 1;
  uint256 public constant ID_TYPE_2 = 2;
  uint256 public constant ID_TYPE_3 = 3;
  uint256 public constant ID_TYPE_4 = 4;
  uint256 public constant ID_TYPE_5 = 5;
  uint256 public constant ID_TYPE_6 = 6;
  uint256 public constant ID_TYPE_7 = 7;
  uint256 public constant ID_TYPE_8 = 8;
  uint256 public constant ID_TYPE_9 = 9;
  uint256 public constant ID_TYPE_10 = 10;

  constructor() ERC1155("UniqueIdentity") {}

  /**
   * @dev Gets the token name.
   * @return string representing the token name
   */
  function name() public pure returns (string memory) {
    return "Unique Identity";
  }

  /**
   * @dev Gets the token symbol.
   * @return string representing the token symbol
   */
  function symbol() public pure returns (string memory) {
    return "UID";
  }

  function mint(uint256 id) public payable {
    _mint(_msgSender(), id, 1, "");
  }
}
