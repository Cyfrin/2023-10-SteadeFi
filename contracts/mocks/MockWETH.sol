// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockWETH is ERC20  {
  constructor() ERC20('MockWETH', 'WETH') {}

  receive() external payable {}

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }

  function deposit() public payable {
      _mint(msg.sender, msg.value);
    }

  function withdraw(uint wad) public {
    require(balanceOf(msg.sender) >= wad);
      _burn(msg.sender, wad);
      payable(msg.sender).transfer(wad);
  }

}
