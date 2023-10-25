// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract MockArbSys {
  function arbBlockNumber() external view returns (uint256) {
    return block.number;
  }

  function arbBlockHash() external view returns (bytes32) {
    return blockhash(block.number);
  }
}
