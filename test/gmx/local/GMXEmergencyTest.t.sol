// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import { console, console2 } from "forge-std/Test.sol";
import { TestUtils } from "../../helpers/TestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GMXMockVaultSetup } from "./GMXMockVaultSetup.t.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";
import { GMXTestHelper } from "./GMXTestHelper.sol";

contract GMXEmergencyTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {
  uint256 deadline = block.timestamp + 1000;

  function test_emergencyPause() external {
    vm.startPrank(owner);
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      2e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    // uint256 equityBefore = vault.equityValue();
    // uint256 lpAmtBefore = vault.lpAmt();
    // uint256 debtRatioBefore = vault.debtRatio();
    (uint256 debtABefore, uint256 debtBBefore) = vault.debtAmt();

    vault.emergencyPause();
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    uint256 equityAfter = vault.equityValue();
    uint256 lpAmtAfter = vault.lpAmt();
    uint256 debtRatioAfter = vault.debtRatio();
    (uint256 debtAAfter, uint256 debtBAfter) = vault.debtAmt();

    // console2.log("equityBefore", equityBefore);
    // console2.log("equityAfter", equityAfter);
    // console2.log("lpAmtBefore", lpAmtBefore);
    // console2.log("lpAmtAfter", lpAmtAfter);
    // console2.log("debtRatioBefore", debtRatioBefore);
    // console2.log("debtRatioAfter", debtRatioAfter);
    // console2.log("WETH balance after", WETH.balanceOf(address(vault)));
    // console2.log("USDC balance after", USDC.balanceOf(address(vault)));

    assertEq(equityAfter, 0, "equityAfter not zero");
    assertEq(lpAmtAfter, 0, "lpAmtAfter not zero");
    assertEq(debtRatioAfter, 0, "debtRatioAfter not zero");
    assertEq(debtABefore, debtAAfter, "debtA should not change");
    assertEq(debtBBefore, debtBAfter, "debtB should not change");
    assertGt(WETH.balanceOf(address(vault)), 0, "WETH balance should not be zero");
    assertGt(USDC.balanceOf(address(vault)), 0, "USDC balance should not be zero");
    assertEq(uint256(vault.store().status), 10, "vault status not set to paused");
  }

  function test_emergencyClose() external {
    vm.startPrank(owner);
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      2e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    vault.emergencyPause();
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    vault.emergencyClose(deadline);
    (uint256 debtAAfter, uint256 debtBAfter) = vault.debtAmt();

    assertEq(debtAAfter, 0, "debtAAfter not zero");
    assertEq(debtBAfter, 0, "debtBAfter not zero");
    assertEq(uint256(vault.store().status), 12, "vault status not set to closed");
  }

  function test_emergencyWithdraw() external {
    vm.startPrank(user1);
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    vm.startPrank(owner);
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      2e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    vault.emergencyPause();
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
    vault.emergencyClose(deadline);

    uint256 WETHBalanceBefore = WETH.balanceOf(address(user1));

    vm.startPrank(user1);
    vault.emergencyWithdraw(vault.balanceOf(address(user1)));

    uint256 WETHBalanceAfter = WETH.balanceOf(address(user1));

    assertTrue(WETHBalanceAfter > WETHBalanceBefore, "WETHBalanceAfter not greater than WETHBalanceBefore");
    assertEq(vault.balanceOf(user1), 0, "user1 balance not zero");
  }

  function test_emergencyResume1() external {
    vm.startPrank(owner);
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      2e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    vault.emergencyPause();
    assertEq(uint256(vault.store().status), 10, "vault should be paused");
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    vault.emergencyResume();

    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    uint256 WETHBalanceAfter = WETH.balanceOf(address(vault));
    uint256 USDCBalanceAfter = USDC.balanceOf(address(vault));
    uint256 lpAmtAfter = vault.lpAmt();

    assertEq(WETHBalanceAfter, 0, "WETHBalanceAfter not zero");
    assertEq(USDCBalanceAfter, 0, "USDCBalanceAfter not zero");
    assertTrue(lpAmtAfter > 0, "lpAmtAfter not greater than zero");
    assertEq(uint256(vault.store().status), 0, "vault should be Open");
    require(roughlyEqual(vault.store().leverage, vault.leverage(), 1e17), "leverage should be 3");
  }

  function test_beforeEmergencyResumeChecks() external {
    vm.startPrank(owner);

    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.emergencyResume();
  }

  function test_beforeEmergencyCloseChecks() external {
    vm.startPrank(owner);

    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.emergencyClose(deadline);
  }

  function test_beforeEmergencyWithdrawChecks() external {
    vm.startPrank(owner);
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      2e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    vault.emergencyPause();
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    uint256 bal = vault.balanceOf(address(owner));
    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.emergencyWithdraw(bal);

    vault.emergencyClose(deadline);

    expectRevert("EmptyWithdrawAmount()");
    vault.emergencyWithdraw(0);

    expectRevert("InsufficientWithdrawBalance()");
    vault.emergencyWithdraw(bal + 1);
  }

}
