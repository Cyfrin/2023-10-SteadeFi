// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
  uint8 _decimals;

  constructor(uint8 __decimals) ERC20('ERC20Mock', 'E20M') {
    _decimals = __decimals;
  }

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }
}
