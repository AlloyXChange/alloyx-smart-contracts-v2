// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SortedGoldfinchTranches
 * @notice A editable sorted list of tranch pool addresses according to score
 * @author AlloyX
 */
contract SortedGoldfinchTranches is Ownable {
  mapping(address => uint256) public scores;
  mapping(address => address) _nextTranches;
  uint256 public listSize;
  address constant GUARD = address(1);

  constructor() public {
    _nextTranches[GUARD] = GUARD;
  }

  /**
   * @notice A method to add a tranch with a score
   * @param tranch the address of the tranch pool address
   * @param score the score of the tranch pool address
   */
  function addTranch(address tranch, uint256 score) public {
    require(_nextTranches[tranch] == address(0));
    address index = _findIndex(score);
    scores[tranch] = score;
    _nextTranches[tranch] = _nextTranches[index];
    _nextTranches[index] = tranch;
    listSize++;
  }

  /**
   * @notice A method to increase the score of a tranch pool
   * @param tranch the address of the tranch pool address
   * @param score the score of the tranch pool address to increase by
   */
  function increaseScore(address tranch, uint256 score) public {
    updateScore(tranch, scores[tranch] + score);
  }

  /**
   * @notice A method to reduce the score of a tranch pool
   * @param tranch the address of the tranch pool address
   * @param score the score of the tranch pool address to reduce by
   */
  function reduceScore(address tranch, uint256 score) public {
    updateScore(tranch, scores[tranch] - score);
  }

  /**
   * @notice A method to update the score of a tranch pool
   * @param tranch the address of the tranch pool address
   * @param newScore the score of the tranch pool address to update to
   */
  function updateScore(address tranch, uint256 newScore) public {
    require(_nextTranches[tranch] != address(0));
    address prevTranch = _findPrevTranch(tranch);
    address nextTranch = _nextTranches[tranch];
    if (_verifyIndex(prevTranch, newScore, nextTranch)) {
      scores[tranch] = newScore;
    } else {
      removeTranch(tranch);
      addTranch(tranch, newScore);
    }
  }

  /**
   * @notice A method to remove the tranch pool address
   * @param tranch the address of the tranch pool address
   */
  function removeTranch(address tranch) public {
    require(_nextTranches[tranch] != address(0));
    address prevTranch = _findPrevTranch(tranch);
    _nextTranches[prevTranch] = _nextTranches[tranch];
    _nextTranches[tranch] = address(0);
    scores[tranch] = 0;
    listSize--;
  }

  /**
   * @notice A method to get the top k tranch pools
   * @param k the top k tranch pools
   */
  function getTop(uint256 k) public view returns (address[] memory) {
    require(k <= listSize);
    address[] memory tranchLists = new address[](k);
    address currentAddress = _nextTranches[GUARD];
    for (uint256 i = 0; i < k; ++i) {
      tranchLists[i] = currentAddress;
      currentAddress = _nextTranches[currentAddress];
    }
    return tranchLists;
  }

  /**
   * @notice A method to verify the next tranch is valid
   * @param prevTranch the previous tranch pool address
   * @param newValue the new score
   * @param nextTranch the next tranch pool address
   */
  function _verifyIndex(
    address prevTranch,
    uint256 newValue,
    address nextTranch
  ) internal view returns (bool) {
    return
      (prevTranch == GUARD || scores[prevTranch] >= newValue) &&
      (nextTranch == GUARD || newValue > scores[nextTranch]);
  }

  /**
   * @notice A method to find the index of the newly added score
   * @param newValue the new score
   */
  function _findIndex(uint256 newValue) internal view returns (address) {
    address candidateAddress = GUARD;
    while (true) {
      if (_verifyIndex(candidateAddress, newValue, _nextTranches[candidateAddress]))
        return candidateAddress;
      candidateAddress = _nextTranches[candidateAddress];
    }
    return address(0);
  }

  /**
   * @notice A method to tell if the previous tranch is ahead of current tranch
   * @param tranch the current tranch pool
   * @param prevTranch the previous tranch pool
   */
  function _isPrevTranch(address tranch, address prevTranch) internal view returns (bool) {
    return _nextTranches[prevTranch] == tranch;
  }

  /**
   * @notice A method to find the previous tranch pool
   * @param tranch the current tranch pool
   */
  function _findPrevTranch(address tranch) internal view returns (address) {
    address currentAddress = GUARD;
    while (_nextTranches[currentAddress] != GUARD) {
      if (_isPrevTranch(tranch, currentAddress)) return currentAddress;
      currentAddress = _nextTranches[currentAddress];
    }
    return address(0);
  }
}
