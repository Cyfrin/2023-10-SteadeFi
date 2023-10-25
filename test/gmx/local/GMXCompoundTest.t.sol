// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import { console, console2 } from "forge-std/Test.sol";
import { TestUtils } from "../../helpers/TestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GMXMockVaultSetup } from "./GMXMockVaultSetup.t.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";
import { GMXTestHelper } from "./GMXTestHelper.sol";

contract GMXCompoundTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {
  function test_compound() external {
    vm.startPrank(owner);

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    // airdrop ARB reward tokens
    deal(address(ARB), address(vault), 10e18);

    // state before
    uint256 lpAmtBefore = vault.lpAmt();
    assertTrue(ARB.balanceOf(address(vault)) > 0, "arb balance should be > 0");

    // compound called by keepers
    compoundParams.tokenIn = address(ARB);
    compoundParams.tokenOut = address(USDC);
    compoundParams.slippage = SLIPPAGE;
    compoundParams.executionFee = EXECUTION_FEE;

    vault.compound{value: EXECUTION_FEE}(compoundParams);

    assertEq(uint256(vault.store().status), 8, "vault status should be compound(8)");
    _assertZeroTokenBalances();

    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    // state after
    uint256 lpAmtAfter = vault.lpAmt();
    assertGt(lpAmtAfter, lpAmtBefore, "lpAmt should be > lpAmtBefore");
    assertEq(ARB.balanceOf(address(vault)), 0, "arb balance should be 0");
    assertEq(uint256(vault.store().status), 0, "vault status should be 0");
    _assertZeroTokenBalances();
  }

  function test_processCompoundCancellation() external {
    vm.startPrank(owner);

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    // airdrop ARB reward tokens
    deal(address(ARB), address(vault), 10e18);

    // state before
    uint256 lpAmtBefore = vault.lpAmt();
    assertTrue(ARB.balanceOf(address(vault)) > 0, "arb balance should be > 0");

    // compound called by keepers
    compoundParams.tokenIn = address(ARB);
    compoundParams.tokenOut = address(USDC);
    compoundParams.slippage = SLIPPAGE;
    compoundParams.executionFee = EXECUTION_FEE;

    vault.compound{value: EXECUTION_FEE}(compoundParams);

    assertEq(uint256(vault.store().status), 8, "vault status should be compound(8)");
    assertTrue(ARB.balanceOf(address(vault)) == 0, "arb balance should be = 0");
    uint256 usdcBalanceBefore = USDC.balanceOf(address(vault));

    mockExchangeRouter.cancelDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    assertEq(uint256(vault.store().status), 9, "vault status should be compound failed");
    assertTrue(USDC.balanceOf(address(vault)) > usdcBalanceBefore, "usdc balance should be > usdcBalanceBefore");
    assertEq(vault.lpAmt(), lpAmtBefore, "lpAmt should be same as lpAmtBefore");
  }

  function test_beforeCompoundChecks() external {
    vm.startPrank(owner);

    compoundParams.tokenIn = address(ARB);
    compoundParams.tokenOut = address(USDC);
    compoundParams.slippage = SLIPPAGE;
    compoundParams.executionFee = EXECUTION_FEE;

    // airdrop ARB reward tokens
    deal(address(ARB), address(vault), 10e18);

    uint256 id = vm.snapshot();
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.compound{value: EXECUTION_FEE}(compoundParams);

    vm.revertTo(id);
    compoundParams.executionFee = 0;
    expectRevert("InsufficientExecutionFeeAmount()");
    vault.compound{value: 0}(compoundParams);

    // vm.revertTo(id);
    // mockChainlinkOracle.set(address(ARB), 0, 18);
    // expectRevert("InsufficientDepositAmount()");
    // vault.compound{value: EXECUTION_FEE}(compoundParams);

  }

  function test_beforeProcessCompoundChecks() external {
    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.processCompound();
  }

  function test_beforeProcessCompoundCancellationChecks() external {
    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.processCompoundCancellation();
  }
}
