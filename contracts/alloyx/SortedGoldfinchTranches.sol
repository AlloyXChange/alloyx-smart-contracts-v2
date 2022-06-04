// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SortedGoldfinchTranches is Ownable {
  mapping(address => uint256) public scores;
  mapping(address => address) _nextTranches;
  uint256 public listSize;
  address constant GUARD = address(1);

  constructor() public {
    _nextTranches[GUARD] = GUARD;
  }

  function addTranch(address tranch, uint256 score) public {
    require(_nextTranches[tranch] == address(0));
    address index = _findIndex(score);
    scores[tranch] = score;
    _nextTranches[tranch] = _nextTranches[index];
    _nextTranches[index] = tranch;
    listSize++;
  }

  function increaseScore(address tranch, uint256 score) public {
    updateScore(tranch, scores[tranch] + score);
  }

  function reduceScore(address tranch, uint256 score) public {
    updateScore(tranch, scores[tranch] - score);
  }

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

  function removeTranch(address tranch) public {
    require(_nextTranches[tranch] != address(0));
    address prevTranch = _findPrevTranch(tranch);
    _nextTranches[prevTranch] = _nextTranches[tranch];
    _nextTranches[tranch] = address(0);
    scores[tranch] = 0;
    listSize--;
  }

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

  function _verifyIndex(
    address prevTranch,
    uint256 newValue,
    address nextTranch
  ) internal view returns (bool) {
    return
      (prevTranch == GUARD || scores[prevTranch] >= newValue) &&
      (nextTranch == GUARD || newValue > scores[nextTranch]);
  }

  function _findIndex(uint256 newValue) internal view returns (address) {
    address candidateAddress = GUARD;
    while (true) {
      if (_verifyIndex(candidateAddress, newValue, _nextTranches[candidateAddress]))
        return candidateAddress;
      candidateAddress = _nextTranches[candidateAddress];
    }
    return address(0);
  }

  function _isPrevTranch(address tranch, address prevTranch) internal view returns (bool) {
    return _nextTranches[prevTranch] == tranch;
  }

  function _findPrevTranch(address tranch) internal view returns (address) {
    address currentAddress = GUARD;
    while (_nextTranches[currentAddress] != GUARD) {
      if (_isPrevTranch(tranch, currentAddress)) return currentAddress;
      currentAddress = _nextTranches[currentAddress];
    }
    return address(0);
  }
}
