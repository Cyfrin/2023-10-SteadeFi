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

contract GMXDepositTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {
  function test_createDeposit() external {
    vm.startPrank(user1);
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    // vault status should be set to deposit
    assertEq(uint256(vault.store().status), 1, "vault status not set to deposit");

    // vault balances should be 0
    assertEq(IERC20(WETH).balanceOf(address(vault)), 0, "vault weth balance not 0");
    assertEq(IERC20(USDC).balanceOf(address(vault)), 0, "vault usdc balance not 0");

    // deposit cache should be populated
    GMXTypes.DepositCache memory depositCache = vault.store().depositCache;
    assertEq(depositCache.user, address(user1), "depositCache user not user1");
    assertEq(depositCache.depositValue,  vault.convertToUsdValue(depositParams.token, depositParams.amt), "depositCache depositValue not correct");
    assertEq(depositCache.sharesToUser, 0, "depositCache sharesToUser not 0");

    // deposit key should not be 0
    require(depositCache.depositKey != bytes32(0), "depositKey should not be 0");
  }

  function test_createDepositWithLP() external {
    vm.startPrank(user1);
    address pair = address(vault.store().lpToken);

    deal(pair, user1, 1 ether);
    IERC20(pair).approve(address(vault), 10e18);
    _createDeposit(address(pair), 0.00001e18, 0, SLIPPAGE, EXECUTION_FEE);

    // vault status should be set to deposit
    assertEq(uint256(vault.store().status), 1, "vault status not set to deposit");

    // vault balances should be 0
    assertEq(IERC20(WETH).balanceOf(address(vault)), 0, "vault weth balance not 0");
    assertEq(IERC20(USDC).balanceOf(address(vault)), 0, "vault usdc balance not 0");

    // deposit cache should be populated
    GMXTypes.DepositCache memory depositCache = vault.store().depositCache;
    assertEq(depositCache.user, address(user1), "depositCache user not user1");
    assertEq(depositCache.sharesToUser, 0, "depositCache sharesToUser not 0");

    // deposit key should not be 0
    require(depositCache.depositKey != bytes32(0), "depositKey should not be 0");

    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    require(roughlyEqual(vault.store().leverage, vault.leverage(), 1e17), "leverage should be 3");

    // lp amt should be greater than 0
    assertGt(vault.lpAmt(), 0, "lpAmt should be greater than 0");
  }

  function test_createNativeDeposit() external {
    vm.startPrank(user1);
    _createNativeDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    // vault status should be set to deposit
    assertEq(uint256(vault.store().status), 1);

    // vault balances should be 0
    assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
    assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

    // deposit cache should be populated
    GMXTypes.DepositCache memory depositCache = vault.store().depositCache;
    assertEq(depositCache.user, address(user1));
    assertEq(depositCache.depositValue,  vault.convertToUsdValue(depositParams.token, depositParams.amt));
    assertEq(depositCache.sharesToUser, 0);

    // deposit key should not be 0
    require(depositCache.depositKey != bytes32(0), "depositKey should not be 0");
  }

  function test_processDeposit() external {
    vm.startPrank(user1);
    _createNativeDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    // vault status should be set to open
    assertEq(uint256(vault.store().status), 0);

    // leverage should be around 3
    require(roughlyEqual(vault.store().leverage, vault.leverage(), 1e17), "leverage should be 3");

    // lp amt should be greater than 0
    assertGt(vault.lpAmt(), 0, "lpAmt should be greater than 0");
  }

  function test_processDepositCancel() external {
    vm.startPrank(user1);
    uint256 userEthBalance = address(user1).balance;
    uint256 userUsdcBalance = IERC20(USDC).balanceOf(address(user1));

    _createNativeDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    // cancel deposit
    mockExchangeRouter.cancelDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    // lending vaults should be repaid
    assertEq(mockLendingVaultWETH.maxRepay(address(vault)), 0);
    assertEq(mockLendingVaultUSDC.maxRepay(address(vault)), 0);

    // user should be repaid in ETH and USDC
    assertEq(address(user1).balance, userEthBalance);
    assertEq(IERC20(USDC).balanceOf(address(user1)), userUsdcBalance);

    // status should be reset to open
    assertEq(uint256(vault.store().status), 0);
  }

  function test_processDepositFailure() external {
    vm.startPrank(user1);

    uint256 lpAmtBefore = vault.lpAmt();

    // setup failed deposit
    _createDeposit(address(WETH), 1e18, 2000 ether, SLIPPAGE, EXECUTION_FEE);
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    uint256 userWETHBalanceBefore = IERC20(WETH).balanceOf(address(user1));
    uint256 userUSDCBalanceBefore = IERC20(USDC).balanceOf(address(user1));

    // status should be set to 2 (deposit failure)
    assertEq(uint256(vault.store().status), 2);

    // keeper calls processDepositFailure()
    vault.processDepositFailure{value: EXECUTION_FEE} (SLIPPAGE, EXECUTION_FEE);

    // lp amt should not increase (as processDepositFailure removes liquidity)
    require(vault.lpAmt() == lpAmtBefore, "lpAmt should not increase");

    // wait for GMX callback afterWithdrawExecution() and processDepositFailureLiquidityWithdrawal()
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    // Borrowed assets should be repaid
    assertEq(mockLendingVaultWETH.maxRepay(address(vault)), 0);
    assertEq(mockLendingVaultUSDC.maxRepay(address(vault)), 0);

    // user should get back assets
    assertGt(IERC20(WETH).balanceOf(address(user1)), userWETHBalanceBefore, "user should get back weth");
    assertGe(IERC20(USDC).balanceOf(address(user1)), userUSDCBalanceBefore, "user should get back usdc");

    // status should be reset to open
    assertEq(uint256(vault.store().status), 0);
  }

  function test_beforeDepositChecks() external {
    vm.startPrank(user1);
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("NotAllowedInCurrentVaultStatus()");
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    expectRevert("InsufficientExecutionFeeAmount()");
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, 0.0001 ether);

    expectRevert("InvalidDepositToken()");
    _createDeposit(address(ARB), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("InsufficientDepositAmount()");
    _createDeposit(address(WETH), 0, 0, SLIPPAGE, EXECUTION_FEE);

    expectRevert("InsufficientSlippageAmount()");
    _createDeposit(address(WETH), 1e18, 0, 0, EXECUTION_FEE);

    expectRevert("InsufficientDepositAmount()");
    _createDeposit(address(WETH), 1e5, 0, SLIPPAGE, EXECUTION_FEE);

    deal(address(WETH), user1, 1000e18);
    expectRevert("InsufficientLendingLiquidity()");
    _createDeposit(address(WETH), 1000e18, 0, SLIPPAGE, EXECUTION_FEE);
  }

  function test_beforeNativeDepositChecks() external {
    vm.startPrank(user1);
    expectRevert("InvalidNativeTokenAddress()");
    _createNativeDeposit(address(ARB), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    depositParams.token = address(WETH);
    expectRevert("OnlyNonNativeDepositToken()");
    vaultARBUSDC.depositNative{value: depositParams.executionFee}(depositParams);

    expectRevert("EmptyDepositAmount()");
    _createNativeDeposit(address(WETH), 0, 0, SLIPPAGE, 0);

    depositParams.amt = 1e18;
    expectRevert("DepositAndExecutionFeeDoesNotMatchMsgValue()");
    vault.depositNative{value: (depositParams.executionFee + depositParams.amt + 1)}(depositParams);

  }

  function test_afterDepositChecks() external {
    vm.startPrank(user1);
    // setup deposit
    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      2e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );
    uint256 snapshot = vm.snapshot();

    // setup failed deposit due high minSharesAmt
    _createDeposit(address(WETH), 1e18, 2000 ether, SLIPPAGE, EXECUTION_FEE);

    // Do not expect revert, but DepositFailed(reason) event and status set to deposit failed (2)
    vm.expectEmit(true, true, true, true);
    emit DepositFailed(getBytes("InsufficientSharesMinted()"));
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
    assertEq(uint256(vault.store().status), 2);

    vm.revertTo(snapshot);
    // setup failed deposit due equity did not increase
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    vm.expectEmit(true, true, true, true);
    emit DepositFailed(hex"4e487b710000000000000000000000000000000000000000000000000000000000000011");
    mockExchangeRouter.executeMockDeposit(
      address(WETH),
      address(USDC),
      0,
      0,
      0,
      0,
      address(vault),
      address(callback)
    );
    assertEq(uint256(vault.store().status), 2);

    vm.revertTo(snapshot);
    // setup failed deposit due insufficient LP minted
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);
    mockLendingVaultUSDC.mockSetDebt(address(vault), 0e6);

    vm.expectEmit(true, true, true, true);
    emit DepositFailed(getBytes("InsufficientLPTokensMinted()"));
    mockExchangeRouter.executeMockDeposit(
      address(WETH),
      address(USDC),
      1,
      0,
      0,
      0,
      address(vault),
      address(callback)
    );

    vm.revertTo(snapshot);
    // setup failed deposit due invalid debt ratio
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);
    mockLendingVaultUSDC.mockSetDebt(address(vault), 0e6);

    vm.expectEmit(true, true, true, true);
    emit DepositFailed(getBytes("InvalidDebtRatio()"));
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );
  }

  function test_beforeProcessDepositCancellationChecks() external {
    vm.startPrank(user1);

    expectRevert("NotAllowedInCurrentVaultStatus()");
    vault.processDepositCancellation();
  }

  function test_mintFee() external {
    vm.startPrank(user1);
    uint256 treasuryBal = IERC20(vault).balanceOf(address(treasury));

    // setup deposit
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    skip(30 days);
    // setup another deposit
    _createDeposit(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vault),
      address(callback)
    );

    // treasury balance should increase
    require(IERC20(vault).balanceOf(address(treasury)) > treasuryBal, "treasury balance should increase");
  }


}
