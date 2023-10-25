// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IGMXVaultEvents {

  /* ======================== EVENTS ========================= */

  event KeeperUpdated(address keeper, bool approval);
  event TreasuryUpdated(address treasury);
  event SwapRouterUpdated(address router);
  event TroveUpdated(address trove);
  event CallbackUpdated(address callback);
  event FeePerSecondUpdated(uint256 feePerSecond);
  event ParameterLimitsUpdated(
    uint256 debtRatioStepThreshold,
    uint256 debtRatioUpperLimit,
    uint256 debtRatioLowerLimit,
    int256 deltaUpperLimit,
    int256 deltaLowerLimit
  );
  event MinSlippageUpdated(uint256 minSlippage);
  event MinExecutionFeeUpdated(uint256 minExecutionFee);

  event DepositCreated(
    address indexed user,
    address asset,
    uint256 assetAmt
  );
  event DepositCompleted(
    address indexed user,
    uint256 shareAmt,
    uint256 equityBefore,
    uint256 equityAfter
  );
  event DepositCancelled(
    address indexed user
  );
  event DepositFailed(bytes reason);

  event WithdrawCreated(address indexed user, uint256 shareAmt);
  event WithdrawCompleted(
    address indexed user,
    address token,
    uint256 tokenAmt
  );
  event WithdrawCancelled(address indexed user);
  event WithdrawFailed(bytes reason);

  event RebalanceSuccess(
    uint256 svTokenValueBefore,
    uint256 svTokenValueAfter
  );
  event RebalanceOpen(
    bytes reason,
    uint256 svTokenValueBefore,
    uint256 svTokenValueAfter
  );
  event RebalanceCancelled();

  event CompoundCompleted();
  event CompoundCancelled();

  event EmergencyPause();
  event EmergencyResume();
  event EmergencyClose(
    uint256 repayTokenAAmt,
    uint256 repayTokenBAmt
  );
  event EmergencyWithdraw(
    address indexed user,
    uint256 sharesAmt,
    address assetA,
    uint256 assetAAmt,
    address assetB,
    uint256 assetBAmt
  );
}
