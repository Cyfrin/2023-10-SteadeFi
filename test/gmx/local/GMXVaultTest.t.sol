// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import { console, console2 } from "forge-std/Test.sol";
import { TestUtils } from "../../helpers/TestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GMXMockVaultSetup } from "./GMXMockVaultSetup.t.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";
import { GMXTestHelper } from "./GMXTestHelper.sol";

import { IDeposit } from "../../../contracts/interfaces/protocols/gmx/IDeposit.sol";
import { IEvent } from "../../../contracts/interfaces/protocols/gmx/IEvent.sol";

contract GMXVaultTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {
  function test_receive() external {
    vm.startPrank(owner);
    // setup refundee
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    // state before
    uint256 ethBalanceBefore = owner.balance;

    assertTrue(vault.store().refundee == address(owner), "refundee should be owner");

    // receive ETH
    vm.startPrank(address(mockExchangeRouter));
    deal(address(mockExchangeRouter), 1 ether);
    (bool s, ) = address(vault).call{value: 1 ether}("");
    assertTrue(s, "receive ETH should succeed");

    // state after
    uint256 ethBalanceAfter = owner.balance;
    assertEq(ethBalanceAfter, ethBalanceBefore + 1 ether, "eth balance should be +1 ether");
  }

}
