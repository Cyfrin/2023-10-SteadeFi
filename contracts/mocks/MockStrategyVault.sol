// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { ILendingVault } from '../interfaces/lending/ILendingVault.sol';

contract MockStrategyVault is ERC20 {
  ILendingVault lendingVaultA;
  ILendingVault lendingVaultB;

  constructor() ERC20('MockStrategyVault', 'MSV') {}

  function deposit(uint256 amount) external {
    _mint(msg.sender, amount);
  }

  function withdraw(uint256 amount) external {
    _burn(msg.sender, amount);
  }

  function borrow(uint256 amount, address lendingVault) external {
    ILendingVault(lendingVault).borrow(amount);
  }

  function repay(uint256 amount, address lendingVault) external {
    ILendingVault(lendingVault).repay(amount);
  }
}
