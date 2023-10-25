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

contract GMXRebalanceTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {

  function test_rebalanceAdd() external {
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

    // set vault out of balance - underleveraged
    mockLendingVaultUSDC.mockSetDebt(address(vault), 3100e6);
    uint256 debtRatioBefore = vault.debtRatio();

    // rebalance vault
    _calcRebalanceParamsDebt();
    vault.rebalanceAdd(rebalanceAddParams);

    // vault status should be rebalance add
    assertEq(uint256(vault.store().status), 5);

    // process rebalance
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
    require(vault.debtRatio() > debtRatioBefore, "debt ratio did not increase");
    require(roughlyEqual(vault.debtRatio(), 0.67e18, 0.1e18));
  }

  function test_rebalanceAddDelta() external {
    vm.startPrank(user1);
    _createAndExecuteDepositNeutral(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    // set vault out of balance - delta high
    mockLendingVaultWETH.mockSetDebt(address(vaultNeutral), 0.1e18);
    uint256 deltaBefore = abs(vaultNeutral.delta());

    _calcRebalanceParamsDelta();
    vaultNeutral.rebalanceAdd(rebalanceAddParams);

    // vault status should be rebalance add
    assertEq(uint256(vaultNeutral.store().status), 5);

    // process rebalance
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vaultNeutral),
      address(callbackNeutral)
    );

    assertLt(abs(vaultNeutral.delta()), deltaBefore, "delta did not decrease");
    // console.log("delta after", abs(vaultNeutral.delta()));
  }

  function test_rebalanceRemove() external {
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

    // set vault out of balance
    mockLendingVaultUSDC.mockSetDebt(address(vault), 3300e6);
    uint256 debtRatioBefore = vault.debtRatio();

    // rebalance vault
    _calcRebalanceParamsDebt();
    vault.rebalanceRemove(rebalanceRemoveParams);

    // vault status should be rebalance remove
    assertEq(uint256(vault.store().status), 6);

    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    vm.startPrank(address(vault));
    swapParams.tokenIn = address(WETH);
    swapParams.tokenOut = address(USDC);
    swapParams.amountIn = WETH.balanceOf(address(vault));
    swapParams.amountOut = 0;
    swapParams.slippage = SLIPPAGE;
    swapParams.deadline = type(uint256).max;
    mockExchangeRouter.swapExactTokensForTokens(swapParams);

    mockLendingVaultUSDC.repay(USDC.balanceOf(address(vault)));

    require(vault.debtRatio() < debtRatioBefore, "debt ratio did not decrease");
    require(roughlyEqual(vault.debtRatio(), 0.67e18, 0.1e18));
  }

   function test_rebalanceRemoveDelta() external {
    vm.startPrank(user1);
    _createAndExecuteDepositNeutral(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    // set vault out of balance - delta low (negative)
    console.log("vault lp amt", vaultNeutral.lpAmt());
    mockExchangeRouter.executeMockDeposit(
      address(WETH),
      address(USDC),
      0,
      0,
      0,
      0.00001e18,
      address(vaultNeutral),
      address(callbackNeutral)
    );
    int256 deltaBefore = vaultNeutral.delta();

    _calcRebalanceParamsDelta();
    vaultNeutral.rebalanceRemove(rebalanceRemoveParams);

    // vault status should be rebalance remove
    assertEq(uint256(vaultNeutral.store().status), 6);

    // process rebalance
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vaultNeutral),
      address(callbackNeutral)
    );

    assertGt(vaultNeutral.delta(), deltaBefore, "delta did not increase");
  }

  function test_rebalanceAddCancellation() external {
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

    // set vault out of balance
    mockLendingVaultUSDC.mockSetDebt(address(vault), 3100e6);

    // rebalance vault
    _calcRebalanceParamsDebt();
    vault.rebalanceAdd(rebalanceAddParams);
    assertEq(uint256(vault.store().status), 5);

    (, uint256 debtBBefore) = vault.debtValue();

    // cancel deposit and trigger cancel rebalanceAdd
    mockExchangeRouter.cancelDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    // loan should be repaid
    (, uint256 debtBAfter) = vault.debtAmt();
    require(debtBAfter < debtBBefore, "debtB did not decrease");
    require(roughlyEqual(debtBAfter, 3100e6, 1e6), "debtB did not decrease to 3100e6");

    // status should be open
    assertEq(uint256(vault.store().status), 0);
  }

  function test_rebalanceRemoveCancellation() external {
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

    // set vault out of balance
    mockLendingVaultUSDC.mockSetDebt(address(vault), 3300e6);

    // rebalance vault
    _calcRebalanceParamsDebt();
    vault.rebalanceRemove(rebalanceRemoveParams);

    // vault status should be rebalance remove
    assertEq(uint256(vault.store().status), 6);

    // cancel deposit and trigger cancel rebalanceWithdraw
    mockExchangeRouter.cancelWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    // status should be open
    assertEq(uint256(vault.store().status), 0);
  }

  function test_beforeRebalanceDebtChecks() external {
    vm.startPrank(user1);
    uint256 snapshot = vm.snapshot();
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.rebalanceAdd(rebalanceAddParams);

    vm.revertTo(snapshot);
    expectRevert("InvalidRebalanceParameters()");
    vault.rebalanceAdd(rebalanceAddParams);

    vm.revertTo(snapshot);
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );
    rebalanceAddParams.rebalanceType = GMXTypes.RebalanceType.Debt;
    expectRevert("InvalidRebalancePreConditions()");
    vault.rebalanceAdd(rebalanceAddParams);
  }

  function test_beforeRebalanceDeltaChecks() external {
    vm.startPrank(user1);

    _createAndExecuteDepositNeutral(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    rebalanceAddParams.rebalanceType = GMXTypes.RebalanceType.Delta;
    expectRevert("InvalidRebalancePreConditions()");
    vaultNeutral.rebalanceAdd(rebalanceAddParams);
  }

  function test_beforeProcessRebalanceChecks() external {
    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.processRebalanceAdd();
  }

  function test_afterRebalanceChecks() external {
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

    // set vault out of balance
    mockLendingVaultUSDC.mockSetDebt(address(vault), 3100e6);

    // rebalance vault
    _calcRebalanceParamsDebt();
    vault.rebalanceAdd(rebalanceAddParams);

    // vault status should be rebalance add
    assertEq(uint256(vault.store().status), 5);

    // set vault out of balance
    mockLendingVaultUSDC.mockSetDebt(address(vault), 2000e6);

    // process rebalance - no revert due try/catch, watch for event instead
    vm.expectEmit(true, true, true, false);
    emit RebalanceOpen(
      getBytes("InvalidDebtRatio()"),
      vault.store().rebalanceCache.healthParams.svTokenValueBefore,
      vault.svTokenValue());
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
  }
}
