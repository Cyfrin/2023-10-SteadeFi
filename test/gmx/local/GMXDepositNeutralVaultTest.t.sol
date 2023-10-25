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

contract GMXDepositNeutralvaultNeutralTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {
  function test_createDepositNeutral() external {
    vm.startPrank(user1);
    _createDepositNeutral(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);

    // vaultNeutral status should be set to deposit
    assertEq(uint256(vaultNeutral.store().status), 1, "vaultNeutral status not set to deposit");

    // vaultNeutral balances should be 0
    assertEq(IERC20(WETH).balanceOf(address(vaultNeutral)), 0, "vaultNeutral weth balance not 0");
    assertEq(IERC20(USDC).balanceOf(address(vaultNeutral)), 0, "vaultNeutral usdc balance not 0");

    // deposit cache should be populated
    GMXTypes.DepositCache memory depositCache = vaultNeutral.store().depositCache;
    assertEq(depositCache.user, address(user1), "depositCache user not user1");
    assertEq(depositCache.depositValue,  vaultNeutral.convertToUsdValue(depositParams.token, depositParams.amt), "depositCache depositValue not correct");
    assertEq(depositCache.sharesToUser, 0, "depositCache sharesToUser not 0");

    // deposit key should not be 0
    require(depositCache.depositKey != bytes32(0), "depositKey should not be 0");
  }

  function test_processDepositNeutral() external {
    vm.startPrank(user1);
    _createDepositNeutral(address(WETH), 1e18, 0, SLIPPAGE, EXECUTION_FEE);
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vaultNeutral),
      address(callbackNeutral)
    );

    // vaultNeutral status should be set to open
    assertEq(uint256(vaultNeutral.store().status), 0);

    // leverage should be around 3
    require(roughlyEqual(vaultNeutral.store().leverage, vaultNeutral.leverage(), 1e17), "leverage should be 3");
    assertLt(abs(vaultNeutral.delta()), 0.01e18, "delta should be close to 0");
    // lp amt should be greater than 0
    assertGt(vaultNeutral.lpAmt(), 0, "lpAmt should be greater than 0");
  }

  function test_processDepositFailureNeutral() external {
    vm.startPrank(user1);

    uint256 lpAmtBefore = vaultNeutral.lpAmt();

    // setup failed deposit
    _createDepositNeutral(address(WETH), 1e18, 2000 ether, SLIPPAGE, EXECUTION_FEE);
    mockExchangeRouter.executeDeposit(
      address(WETH),
      address(USDC),
      address(vaultNeutral),
      address(callbackNeutral)
    );

    uint256 userWETHBalanceBefore = IERC20(WETH).balanceOf(address(user1));
    uint256 userUSDCBalanceBefore = IERC20(USDC).balanceOf(address(user1));

    // status should be set to 2 (deposit failure)
    assertEq(uint256(vaultNeutral.store().status), 2);

    // keeper calls processDepositFailure()
    vaultNeutral.processDepositFailure{value: EXECUTION_FEE} (SLIPPAGE, EXECUTION_FEE);

    // lp amt should not increase (as processDepositFailure removes liquidity)
    require(vaultNeutral.lpAmt() == lpAmtBefore, "lpAmt should not increase");
    // wait for GMX callback afterWithdrawExecution() and processDepositFailureLiquidityWithdrawal()
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vaultNeutral),
      address(callbackNeutral)
    );
    // Borrowed assets should be repaid
    assertEq(mockLendingVaultWETH.maxRepay(address(vaultNeutral)), 0);
    assertEq(mockLendingVaultUSDC.maxRepay(address(vaultNeutral)), 0);

    // user should get back assets
    assertGt(IERC20(WETH).balanceOf(address(user1)), userWETHBalanceBefore, "user should get back weth");
    assertGe(IERC20(USDC).balanceOf(address(user1)), userUSDCBalanceBefore, "user should get back usdc");

    // status should be reset to open
    assertEq(uint256(vaultNeutral.store().status), 0);
  }

}
