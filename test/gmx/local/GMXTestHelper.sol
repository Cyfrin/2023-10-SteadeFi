// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { GMXMockVaultSetup } from "./GMXMockVaultSetup.t.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";
import { IDeposit } from "../../../contracts/interfaces/protocols/gmx/IDeposit.sol";
import { IEvent } from "../../../contracts/interfaces/protocols/gmx/IEvent.sol";
import { ISwap } from "../../../contracts/interfaces/swap/ISwap.sol";

import { console } from "forge-std/console.sol";

contract GMXTestHelper is GMXMockVaultSetup {
    GMXTypes.DepositParams depositParams;
    GMXTypes.WithdrawParams params;
    GMXTypes.RebalanceAddParams rebalanceAddParams;
    GMXTypes.RebalanceRemoveParams rebalanceRemoveParams;
    GMXTypes.BorrowParams borrowParams;
    GMXTypes.RepayParams repayParams;
    GMXTypes.CompoundParams compoundParams;
    IDeposit.Props depositProps;
    IEvent.Props eventProps;
    ISwap.SwapParams swapParams;


    uint256 constant EXECUTION_FEE = 0.001 ether;
    uint256 constant SLIPPAGE = 0.3e2;

  function _createDeposit(address token, uint256 amt, uint256 minSharesAmt, uint256 slippage, uint256 executionFee) internal {
    depositParams.token = token;
    depositParams.amt = amt;
    depositParams.minSharesAmt = minSharesAmt;
    depositParams.slippage = slippage;
    depositParams.executionFee = executionFee;

    vault.deposit{value: depositParams.executionFee}(depositParams);
  }

  function _createDepositNeutral(address token, uint256 amt, uint256 minSharesAmt, uint256 slippage, uint256 executionFee) internal {
    depositParams.token = token;
    depositParams.amt = amt;
    depositParams.minSharesAmt = minSharesAmt;
    depositParams.slippage = slippage;
    depositParams.executionFee = executionFee;

    vaultNeutral.deposit{value: depositParams.executionFee}(depositParams);
  }

  function _createNativeDeposit(address token, uint256 amt, uint256 minSharesAmt, uint256 slippage, uint256 executionFee) internal {
    depositParams.token = token;
    depositParams.amt = amt;
    depositParams.minSharesAmt = minSharesAmt;
    depositParams.slippage = slippage;
    depositParams.executionFee = executionFee;

    vault.depositNative{value: (depositParams.executionFee + depositParams.amt)}(depositParams);
  }

  function _createNativeDepositNeutral(address token, uint256 amt, uint256 minSharesAmt, uint256 slippage, uint256 executionFee) internal {
    depositParams.token = token;
    depositParams.amt = amt;
    depositParams.minSharesAmt = minSharesAmt;
    depositParams.slippage = slippage;
    depositParams.executionFee = executionFee;

    vaultNeutral.depositNative{value: (depositParams.executionFee + depositParams.amt)}(depositParams);
  }

  function _createAndExecuteDeposit(address tokenA, address tokenB, address depositToken, uint256 amt, uint256 minSharesAmt, uint256 slippage, uint256 executionFee) internal {
    _createDeposit(depositToken, amt, minSharesAmt, slippage, executionFee);

    skip(30 seconds);

    mockExchangeRouter.executeDeposit(tokenA, tokenB, address(vault), address(callback));
  }

  function _createAndExecuteDepositNeutral(address tokenA, address tokenB, address depositToken, uint256 amt, uint256 minSharesAmt, uint256 slippage, uint256 executionFee) internal {
    _createDepositNeutral(depositToken, amt, minSharesAmt, slippage, executionFee);

    skip(30 seconds);

    mockExchangeRouter.executeDeposit(tokenA, tokenB, address(vaultNeutral), address(callbackNeutral));
  }

  function _createWithdrawal(address token, uint256 shareAmt, uint256 minWithdrawAmt, uint256 slippage, uint256 executionFee) internal {

    params.token = token;
    params.shareAmt = shareAmt;
    params.minWithdrawTokenAmt = minWithdrawAmt;
    params.slippage = slippage;
    params.executionFee = executionFee;

    vault.withdraw{value: params.executionFee}(params);
  }

  function _createWithdrawalNeutral(address token, uint256 shareAmt, uint256 minWithdrawAmt, uint256 slippage, uint256 executionFee) internal {

    params.token = token;
    params.shareAmt = shareAmt;
    params.minWithdrawTokenAmt = minWithdrawAmt;
    params.slippage = slippage;
    params.executionFee = executionFee;

    vaultNeutral.withdraw{value: params.executionFee}(params);
  }

  function _createAndExecuteWithdrawal(address tokenA, address tokenB, address withdrawToken, uint256 shareAmt, uint256 minWithdrawAmt, uint256 slippage, uint256 executionFee) internal {
    _createWithdrawal(withdrawToken, shareAmt, minWithdrawAmt, slippage, executionFee);

    skip(30 seconds);

    mockExchangeRouter.executeWithdrawal(tokenA, tokenB, address(vault), address(callback));
  }

  function _createAndExecuteWithdrawalNeutral(address tokenA, address tokenB, address withdrawToken, uint256 shareAmt, uint256 minWithdrawAmt, uint256 slippage, uint256 executionFee) internal {
    _createWithdrawalNeutral(withdrawToken, shareAmt, minWithdrawAmt, slippage, executionFee);

    skip(30 seconds);

    mockExchangeRouter.executeWithdrawal(tokenA, tokenB, address(vaultNeutral), address(callbackNeutral));
  }

  function _calcRebalanceParamsDebt() internal {
    // int256 delta = vault.delta();
    uint256 debtRatio = vault.debtRatio();
    uint256 equityValue = vault.equityValue();
    uint256 targetDebt = equityValue * (vault.store().leverage - 1e18) / 1e18;
    (uint256 currentADebt, uint256 currentBDebt) = vault.debtValue();
    uint256 debtValueDiff;
    if (debtRatio < 0.67e18) {
      debtValueDiff = targetDebt - (currentADebt + currentBDebt);

      uint256 borrowBAmt = debtValueDiff
        * 1e18
        / mockChainlinkOracle.consultIn18Decimals(address(vault.store().tokenB)) / 1e12;

      rebalanceAddParams.rebalanceType = GMXTypes.RebalanceType.Debt;
      borrowParams.borrowTokenBAmt = borrowBAmt;
      rebalanceAddParams.borrowParams = borrowParams;
    } else {
      debtValueDiff = (currentADebt + currentBDebt) - targetDebt;
      uint256 lpTokenPrice = mockGMXOracle.getLpTokenValue(address(mockExchangeRouter), address(WETH), address(WETH), address(USDC), true, true);

      uint256 lpAmtToRemove = debtValueDiff
        * 1e18
        / lpTokenPrice * 10050 / 10000;

      rebalanceRemoveParams.rebalanceType = GMXTypes.RebalanceType.Debt;
      rebalanceRemoveParams.lpAmtToRemove = lpAmtToRemove;
    }
  }

  function _calcRebalanceParamsDelta() internal {
    int256 delta = vaultNeutral.delta();
    (uint256 currentADebt,) = vaultNeutral.debtAmt();
    (uint256 currentAAsset,) = vaultNeutral.assetAmt();
    if (delta < vaultNeutral.store().deltaLowerLimit) {
      uint256 tokenAdiff = currentADebt - currentAAsset;
      uint256 tokenAValueDiff = vaultNeutral.convertToUsdValue((address(vaultNeutral.store().tokenA)), tokenAdiff);
      uint256 lpTokenPrice = mockGMXOracle.getLpTokenValue(address(mockExchangeRouter), address(WETH), address(WETH), address(USDC), true, true);

      uint256 lpAmtToRemove = tokenAValueDiff
        * 1e18
        / lpTokenPrice * 10050 / 10000;

      if (lpAmtToRemove > 0) {
        rebalanceRemoveParams.rebalanceType = GMXTypes.RebalanceType.Delta;
        rebalanceRemoveParams.lpAmtToRemove = lpAmtToRemove;
      }
    } else if (delta > vaultNeutral.store().deltaUpperLimit) {
      uint256 tokenAdiff = currentAAsset - currentADebt;

      if(tokenAdiff > 0) {
        rebalanceAddParams.rebalanceType = GMXTypes.RebalanceType.Delta;
        borrowParams.borrowTokenAAmt = tokenAdiff;
        rebalanceAddParams.borrowParams = borrowParams;
      }
    }
  }

  function _assertZeroTokenBalances() internal {
    assertEq(ARB.balanceOf(address(vault)), 0, "arb balance should be 0");
    assertEq(WETH.balanceOf(address(vault)), 0, "weth balance should be 0");
    assertEq(USDC.balanceOf(address(vault)), 0, "usdc balance should be 0");
  }

}
