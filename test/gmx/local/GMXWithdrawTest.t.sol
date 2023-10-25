// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import { console, console2 } from "forge-std/Test.sol";
import { TestUtils } from "../../helpers/TestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GMXMockVaultSetup } from "./GMXMockVaultSetup.t.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";
import { GMXWithdraw } from "../../../contracts/strategy/gmx/GMXWithdraw.sol";
import { GMXTestHelper } from "./GMXTestHelper.sol";

contract GMXWithdrawTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {
  function test_createWithdraw() external {
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
    uint256 lpTokenBalBefore = IERC20(vault.store().lpToken).balanceOf(address(vault));

    _createWithdrawal(address(WETH), 250e18, 0, SLIPPAGE, EXECUTION_FEE);

    // vault status should be set to withdraw
    assertEq(uint256(vault.store().status), 3);

    // vault balances should be 0
    assertEq(IERC20(WETH).balanceOf(address(vault)), 0, "WETH balance should be 0");
    assertEq(IERC20(USDC).balanceOf(address(vault)), 0, "USDC balance should be 0");

    // lp token balance should be reduced
    assertLt(IERC20(vault.store().lpToken).balanceOf(address(vault)), lpTokenBalBefore);

    // withdraw cache should be populated
    GMXTypes.WithdrawCache memory cache = vault.store().withdrawCache;
    assertEq(cache.user, address(user1), "user should be set");
    assertTrue(roughlyEqual(cache.shareRatio, params.shareAmt * SAFE_MULTIPLIER / vault.totalSupply(), 0.1e18), "shareRatio should be set");
    assertEq(cache.lpAmt, cache.shareRatio * lpTokenBalBefore / SAFE_MULTIPLIER, "lpAmt should be set");
    assertGt(cache.withdrawValue, 0, "withdrawValue should be set");
  }

  function test_processWithdraw() external {
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
    _createWithdrawal(address(WETH), 250e18, 0, SLIPPAGE, EXECUTION_FEE);

    // state before
    (uint256 debtABefore, uint256 debtBBefore) = vault.debtValue();
    uint256 userABalanceBefore = IERC20(WETH).balanceOf(address(user1));
    uint256 userBBalanceBefore = IERC20(USDC).balanceOf(address(user1));
    uint256 userSvTokenBalanceBefore = vault.balanceOf(address(user1));

    // process withdrawal
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    require(uint256(vault.store().status) == 0, "status should be reset to open");
    require(vault.balanceOf(address(user1)) < userSvTokenBalanceBefore, "user should have less svToken balance");
    require(IERC20(WETH).balanceOf(address(user1)) >= userABalanceBefore, "user should have more WETH balance");
    require(IERC20(USDC).balanceOf(address(user1)) >= userBBalanceBefore, "user should have more USDC balance");
    (uint256 debtAAfter, uint256 debtBAfter) = vault.debtValue();
    if(debtABefore > 0) require(debtAAfter < debtABefore, "debtA should be less");
    if(debtBBefore > 0) require(debtBAfter < debtBBefore, "debtB should be less");
    require(roughlyEqual(vault.store().leverage, vault.leverage(), 1e17), "leverage should be 3");
  }

  function test_processWithdrawCancel() external {
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
    uint256 lpAmtBefore = vault.lpAmt();
    _createWithdrawal(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    // cancel withdrawal
    mockExchangeRouter.cancelWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    // vault status should be reset to open
    assertEq(uint256(vault.store().status), 0);

    // vault lpAmt should increase to original amount
    require(vault.lpAmt() == lpAmtBefore, "lpAmt should be restored");
  }

  function test_processWithdrawFailure() external {
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

    // Setup withdraw failure due high minWithdrawAmt
    _createWithdrawal(address(WETH), 1e18, 999e18, SLIPPAGE, EXECUTION_FEE);
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    uint256 debtBefore = mockLendingVaultUSDC.maxRepay(address(vault));
    // process withdraw failure
    vm.startPrank(owner);
    vault.processWithdrawFailure{value: 0.01 ether}(0, 0.01 ether);

    require(mockLendingVaultUSDC.maxRepay(address(vault)) > debtBefore, "debt should be more");

    // execute re-added deposit
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
  }

  function test_beforeWithdrawChecks() external {
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

    uint256 id = vm.snapshot();

    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("NotAllowedInCurrentVaultStatus()");
    _createWithdrawal(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    vm.revertTo(id);
    expectRevert("InvalidWithdrawToken()");
    _createWithdrawal(address(ARB), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("EmptyWithdrawAmount()");
    _createWithdrawal(address(WETH), 0, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("InsufficientWithdrawBalance()");
    _createWithdrawal(address(WETH), 10000e18, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("InsufficientWithdrawAmount()");
    _createWithdrawal(address(WETH), 9e15, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("InsufficientSlippageAmount()");
    _createWithdrawal(address(WETH), 1e18, 0, 0, EXECUTION_FEE);

    expectRevert("InsufficientExecutionFeeAmount()");
    _createWithdrawal(address(WETH), 1e18, 0, SLIPPAGE, 0);

    expectRevert("InvalidExecutionFeeAmount()");
    params.token = address(WETH);
    params.shareAmt = 1e18;
    params.minWithdrawTokenAmt = 0;
    params.slippage = SLIPPAGE;
    params.executionFee = 0.01 ether;
    vault.withdraw{value: 0}(params);
  }

  function test_beforeProcessWithdrawChecks() external {
    vm.startPrank(user1);
    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.processWithdraw();
  }

  function test_afterWithdrawChecks() external {
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
    uint256 id = vm.snapshot();
    _createWithdrawal(address(WETH), 1e18, 999e18, SLIPPAGE, EXECUTION_FEE);

    // processWithdraw does not revert as it wraps afterChecks in try/catch
    // check for InsufficientAssetsReceived() + status set to withdraw failed
    vm.expectEmit(true, true, true, true);
    emit WithdrawFailed(getBytes("InsufficientAssetsReceived()"));
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
    assertEq(uint256(vault.store().status), 4);

    // reset vault
    vm.revertTo(id);
    _createWithdrawal(address(WETH), 1000e18, 0, SLIPPAGE, EXECUTION_FEE);

    // check for InvalidEquity();
    mockLendingVaultUSDC.mockSetDebt(address(vault), 0e6);
    vm.expectEmit(true, true, true, true);
    emit WithdrawFailed(getBytes("InvalidEquityAfterWithdraw()"));
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
    assertEq(uint256(vault.store().status), 4);

    // reset vault
    vm.revertTo(id);
    _createWithdrawal(address(WETH), vault.balanceOf(address(user1)) / 4, 0, SLIPPAGE, EXECUTION_FEE);
    mockLendingVaultWETH.mockSetDebt(address(vault), 0.5 ether);

    // check for InsufficientLPTokensBurned();
    vm.expectEmit(true, true, true, true);
    emit WithdrawFailed(getBytes("InsufficientLPTokensBurned()"));
    mockExchangeRouter.executeMockWithdrawal(
      address(WETH),
      address(USDC),
      0.5 ether,
      1000e6,
      3751249999999999,
      0,
      address(vault),
      address(callback)
    );

    // mockExchangeRouter.executeMockWithdrawal(address(vault), address(callback), 3751249999999999, 0.5 ether, 1000e6, 0);
    assertEq(uint256(vault.store().status), 4);

    // reset vault
    vm.revertTo(id);
    _createWithdrawal(address(WETH), vault.balanceOf(address(user1)) / 4, 0, SLIPPAGE, EXECUTION_FEE);
    mockLendingVaultWETH.mockSetDebt(address(vault), 0.2 ether);

    // Check for InvalidDebtRatio
    vm.expectEmit(true, true, true, true);
    emit WithdrawFailed(getBytes("InvalidDebtRatio()"));
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
    assertEq(uint256(vault.store().status), 4);
  }

  function test_beforeProcessWithdrawCancellationChecks() external {
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
    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.processWithdrawCancellation();
  }

  function test_beforeProcessAfterWithdrawFailureChecks() external {
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
    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.processWithdrawFailure{value: 0.01 ether}(0, 0.01 ether);
  }

  function test_beforeProcessAfterWithdrawFailureLiquidityAddedChecks() external {
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
    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.processWithdrawFailureLiquidityAdded();
  }

  function test_mintFee() external {
    vm.startPrank(user1);
    uint256 treasuryBal = IERC20(vault).balanceOf(address(treasury));

    // setup deposits
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    skip(30 days);
    // setup withdraw
    _createWithdrawal(address(WETH), 0.25e18, 0, SLIPPAGE, EXECUTION_FEE);

    // treasury balance should increase
    require(IERC20(vault).balanceOf(address(treasury)) > treasuryBal, "treasury balance should increase");
  }
}
