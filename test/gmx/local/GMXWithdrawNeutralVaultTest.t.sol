// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import { console, console2 } from "forge-std/Test.sol";
import { TestUtils } from "../../helpers/TestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GMXMockVaultSetup } from "./GMXMockVaultSetup.t.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";
import { GMXWithdraw } from "../../../contracts/strategy/gmx/GMXWithdraw.sol";
import { GMXTestHelper } from "./GMXTestHelper.sol";

contract GMXWithdrawNeutralVaultTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {
  function test_processWithdrawNeutral() external {
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
    _createWithdrawalNeutral(address(WETH), 250e18, 0, SLIPPAGE, EXECUTION_FEE);

    // state before
    (uint256 debtABefore, uint256 debtBBefore) = vaultNeutral.debtValue();
    uint256 userABalanceBefore = IERC20(WETH).balanceOf(address(user1));
    uint256 userBBalanceBefore = IERC20(USDC).balanceOf(address(user1));
    uint256 userSvTokenBalanceBefore = vaultNeutral.balanceOf(address(user1));

    // process withdrawal
    mockExchangeRouter.executeWithdrawal(
      address(WETH),
      address(USDC),
      address(vaultNeutral),
      address(callbackNeutral)
    );

    require(uint256(vaultNeutral.store().status) == 0, "status should be reset to open");
    require(vaultNeutral.balanceOf(address(user1)) < userSvTokenBalanceBefore, "user should have less svToken balance");
    require(IERC20(WETH).balanceOf(address(user1)) >= userABalanceBefore, "user should have more WETH balance");
    require(IERC20(USDC).balanceOf(address(user1)) >= userBBalanceBefore, "user should have more USDC balance");
    (uint256 debtAAfter, uint256 debtBAfter) = vaultNeutral.debtValue();
    if(debtABefore > 0) require(debtAAfter < debtABefore, "debtA should be less");
    if(debtBBefore > 0) require(debtBAfter < debtBBefore, "debtB should be less");
    require(roughlyEqual(vaultNeutral.store().leverage, vaultNeutral.leverage(), 1e17), "leverage should be 3");
    assertLt(abs(vaultNeutral.delta()), 0.01e18, "delta should be close to 0");
  }

}
