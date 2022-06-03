// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SortedGoldfinchTranches is Ownable {
  mapping(uint256 => uint256) public scores;
  mapping(uint256 => uint256) _nextTranches;
  uint256 public listSize;
  uint256 constant GUARD = 0;

  constructor() public {
    _nextTranches[GUARD] = GUARD;
  }

  function addTranch(uint256 tranch, uint256 score) public onlyOwner {
    require(_nextTranches[tranch] == 0);
    uint256 index = _findIndex(score);
    scores[tranch] = score;
    _nextTranches[tranch] = _nextTranches[index];
    _nextTranches[index] = tranch;
    listSize++;
  }

  function increaseScore(uint256 tranch, uint256 score) public onlyOwner {
    updateScore(tranch, scores[tranch] + score);
  }

  function reduceScore(uint256 tranch, uint256 score) public onlyOwner {
    updateScore(tranch, scores[tranch] - score);
  }

  function updateScore(uint256 tranch, uint256 newScore) public onlyOwner {
    uint256 prevTranch = _findPrevTranch(tranch);
    uint256 nextTranch = _nextTranches[tranch];
    if (_verifyIndex(prevTranch, newScore, nextTranch)) {
      scores[tranch] = newScore;
    } else {
      removeTranch(tranch);
      addTranch(tranch, newScore);
    }
  }

  function removeTranch(uint256 tranch) public onlyOwner {
    uint256 prevTranch = _findPrevTranch(tranch);
    _nextTranches[prevTranch] = _nextTranches[tranch];
    _nextTranches[tranch] = 0;
    scores[tranch] = 0;
    listSize--;
  }

  function getTop(uint256 k) public view returns (uint256[] memory) {
    require(k <= listSize);
    uint256[] memory tranchLists = new uint256[](k);
    uint256 currentTranch = _nextTranches[GUARD];
    for (uint256 i = 0; i < k; ++i) {
      tranchLists[i] = currentTranch;
      currentTranch = _nextTranches[currentTranch];
    }
    return tranchLists;
  }

  function _verifyIndex(
    uint256 prevTranch,
    uint256 newValue,
    uint256 nextTranch
  ) internal view returns (bool) {
    return
      (prevTranch == GUARD || scores[prevTranch] >= newValue) &&
      (nextTranch == GUARD || newValue > scores[nextTranch]);
  }

  function _findIndex(uint256 newValue) internal view returns (uint256) {
    uint256 candidateAddress = GUARD;
    while (true) {
      if (_verifyIndex(candidateAddress, newValue, _nextTranches[candidateAddress]))
        return candidateAddress;
      candidateAddress = _nextTranches[candidateAddress];
    }
    return 0;
  }

  function _isPrevTranch(uint256 tranch, uint256 prevTranch) internal view returns (bool) {
    return _nextTranches[prevTranch] == tranch;
  }

  function _findPrevTranch(uint256 tranch) internal view returns (uint256) {
    uint256 currentTranch = GUARD;
    while (_nextTranches[currentTranch] != GUARD) {
      if (_isPrevTranch(tranch, currentTranch)) return currentTranch;
      currentTranch = _nextTranches[currentTranch];
    }
    return 0;
  }
}
