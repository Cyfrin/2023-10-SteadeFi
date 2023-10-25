// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IWNT {
  function balanceOf(address user) external returns (uint);
  function approve(address to, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function deposit() external payable;
  function withdraw(uint amount) external;
}
