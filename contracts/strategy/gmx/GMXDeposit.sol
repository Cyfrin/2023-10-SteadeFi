// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IDeposit } from "../../interfaces/protocols/gmx/IDeposit.sol";
import { IWithdrawal } from "../../interfaces/protocols/gmx/IWithdrawal.sol";
import { IEvent } from "../../interfaces/protocols/gmx/IEvent.sol";
import { IOrder } from "../../interfaces/protocols/gmx/IOrder.sol";
import { ISwap } from  "../../interfaces/swap/ISwap.sol";
import { GMXTypes } from "./GMXTypes.sol";
import { GMXReader } from "./GMXReader.sol";
import { GMXChecks } from "./GMXChecks.sol";
import { GMXManager } from "./GMXManager.sol";
import { GMXProcessDeposit } from "./GMXProcessDeposit.sol";

/**
  * @title GMXDeposit
  * @author Steadefi
  * @notice Re-usable library functions for deposit operations for Steadefi leveraged vaults
*/
library GMXDeposit {
  using SafeERC20 for IERC20;

  /* ======================= CONSTANTS ======================= */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ======================== EVENTS ========================= */

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

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
    * @param isNative Boolean as to whether user is depositing native asset (e.g. ETH, AVAX, etc.)
  */
  function deposit(
    GMXTypes.Store storage self,
    GMXTypes.DepositParams memory dp,
    bool isNative
  ) external {
    // Sweep any tokenA/B in vault to the temporary trove for future compouding and to prevent
    // it from being considered as part of depositor's assets
    if (self.tokenA.balanceOf(address(this)) > 0) {
      self.tokenA.safeTransfer(self.trove, self.tokenA.balanceOf(address(this)));
    }
    if (self.tokenB.balanceOf(address(this)) > 0) {
      self.tokenB.safeTransfer(self.trove, self.tokenB.balanceOf(address(this)));
    }

    self.refundee = payable(msg.sender);

    GMXTypes.HealthParams memory _hp;

    _hp.equityBefore = GMXReader.equityValue(self);
    _hp.lpAmtBefore = GMXReader.lpAmt(self);
    _hp.debtRatioBefore = GMXReader.debtRatio(self);
    _hp.deltaBefore = GMXReader.delta(self);

    // Transfer assets from user to vault
    if (isNative) {
      GMXChecks.beforeNativeDepositChecks(self, dp);

      self.WNT.deposit{ value: dp.amt }();
    } else {
      IERC20(dp.token).safeTransferFrom(msg.sender, address(this), dp.amt);
    }

    GMXTypes.DepositCache memory _dc;

    _dc.user = payable(msg.sender);

    if (dp.token == address(self.lpToken)) {
      // If LP token deposited
      _dc.depositValue = self.gmxOracle.getLpTokenValue(
        address(self.lpToken),
        address(self.tokenA),
        address(self.tokenA),
        address(self.tokenB),
        false,
        false
      )
      * dp.amt
      / SAFE_MULTIPLIER;
    } else {
      // If tokenA or tokenB deposited
      _dc.depositValue = GMXReader.convertToUsdValue(
        self,
        address(dp.token),
        dp.amt
      );
    }
    _dc.depositParams = dp;
    _dc.healthParams = _hp;

    self.depositCache = _dc;

    GMXChecks.beforeDepositChecks(self, _dc.depositValue);

    self.status = GMXTypes.Status.Deposit;

    self.vault.mintFee();

    // Borrow assets and create deposit in GMX
    (
      uint256 _borrowTokenAAmt,
      uint256 _borrowTokenBAmt
    ) = GMXManager.calcBorrow(self, _dc.depositValue);

    _dc.borrowParams.borrowTokenAAmt = _borrowTokenAAmt;
    _dc.borrowParams.borrowTokenBAmt = _borrowTokenBAmt;

    GMXManager.borrow(self, _borrowTokenAAmt, _borrowTokenBAmt);

    GMXTypes.AddLiquidityParams memory _alp;

    _alp.tokenAAmt = self.tokenA.balanceOf(address(this));
    _alp.tokenBAmt = self.tokenB.balanceOf(address(this));
    _alp.minMarketTokenAmt = GMXManager.calcMinMarketSlippageAmt(
      self,
      _dc.depositValue,
      dp.slippage
    );
    _alp.executionFee = dp.executionFee;

    _dc.depositKey = GMXManager.addLiquidity(
      self,
      _alp
    );

    self.depositCache = _dc;

    emit DepositCreated(
      _dc.user,
      _dc.depositParams.token,
      _dc.depositParams.amt
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processDeposit(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessDepositChecks(self);

    // We transfer the core logic of this function to GMXProcessDeposit.processDeposit()
    // to allow try/catch here to catch for any issues or any checks in afterDepositChecks() failing.
    // If there are any issues, a DepositFailed event will be emitted and processDepositFailure()
    // should be triggered to refund assets accordingly and reset the vault status to Open again.
    try GMXProcessDeposit.processDeposit(self) {
      // Mint shares to depositor
      self.vault.mint(self.depositCache.user, self.depositCache.sharesToUser);

      self.status = GMXTypes.Status.Open;

      emit DepositCompleted(
        self.depositCache.user,
        self.depositCache.sharesToUser,
        self.depositCache.healthParams.equityBefore,
        self.depositCache.healthParams.equityAfter
      );
    } catch (bytes memory reason) {
      self.status = GMXTypes.Status.Deposit_Failed;

      emit DepositFailed(reason);
    }
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processDepositCancellation(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessDepositCancellationChecks(self);

    // Repay borrowed assets
    GMXManager.repay(
      self,
      self.depositCache.borrowParams.borrowTokenAAmt,
      self.depositCache.borrowParams.borrowTokenBAmt
    );

    // Return user's deposited asset
    // If native token is being withdrawn, we convert wrapped to native
    if (self.depositCache.depositParams.token == address(self.WNT)) {
      self.WNT.withdraw(self.WNT.balanceOf(address(this)));
      (bool success, ) = self.depositCache.user.call{value: address(this).balance}("");
      require(success, "Transfer failed.");
    } else {
      // Transfer requested withdraw asset to user
      IERC20(self.depositCache.depositParams.token).safeTransfer(
        self.depositCache.user,
        self.depositCache.depositParams.amt
      );
    }

    self.status = GMXTypes.Status.Open;

    emit DepositCancelled(self.depositCache.user);
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processDepositFailure(
    GMXTypes.Store storage self,
    uint256 slippage,
    uint256 executionFee
  ) external {
    GMXChecks.beforeProcessAfterDepositFailureChecks(self);

    GMXTypes.RemoveLiquidityParams memory _rlp;

    // If current LP amount is somehow less or equal to amount before, we do not remove any liquidity
    if (GMXReader.lpAmt(self) <= self.depositCache.healthParams.lpAmtBefore) {
      processDepositFailureLiquidityWithdrawal(self);
    } else {
      // Remove only the newly added LP amount
      _rlp.lpAmt = GMXReader.lpAmt(self) - self.depositCache.healthParams.lpAmtBefore;

      // If delta strategy is Long, remove all in tokenB to make it more
      // efficent to repay tokenB debt as Long strategy only borrows tokenB
      if (self.delta == GMXTypes.Delta.Long) {
        address[] memory _tokenASwapPath = new address[](1);
        _tokenASwapPath[0] = address(self.lpToken);
        _rlp.tokenASwapPath = _tokenASwapPath;

        (_rlp.minTokenAAmt, _rlp.minTokenBAmt) = GMXManager.calcMinTokensSlippageAmt(
          self,
          _rlp.lpAmt,
          address(self.tokenB),
          address(self.tokenB),
          slippage
        );
      } else {
        (_rlp.minTokenAAmt, _rlp.minTokenBAmt) = GMXManager.calcMinTokensSlippageAmt(
          self,
          _rlp.lpAmt,
          address(self.tokenA),
          address(self.tokenB),
          slippage
        );
      }

      _rlp.executionFee = executionFee;

      // Remove liqudity
      self.depositCache.withdrawKey = GMXManager.removeLiquidity(
        self,
        _rlp
      );
    }
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processDepositFailureLiquidityWithdrawal(
    GMXTypes.Store storage self
  ) public {
    GMXChecks.beforeProcessAfterDepositFailureLiquidityWithdrawal(self);

    GMXTypes.RepayParams memory _rp;

    _rp.repayTokenAAmt = self.depositCache.borrowParams.borrowTokenAAmt;
    _rp.repayTokenBAmt = self.depositCache.borrowParams.borrowTokenBAmt;

    // Check if swap between assets are needed for repayment based on previous borrow
    (
      bool _swapNeeded,
      address _tokenFrom,
      address _tokenTo,
      uint256 _tokenToAmt
    ) = GMXManager.calcSwapForRepay(self, _rp);

    if (_swapNeeded) {
      ISwap.SwapParams memory _sp;

      _sp.tokenIn = _tokenFrom;
      _sp.tokenOut = _tokenTo;
      _sp.amountIn = IERC20(_tokenFrom).balanceOf(address(this));
      _sp.amountOut = _tokenToAmt;
      _sp.slippage = self.minSlippage;
      _sp.deadline = block.timestamp;
      // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      // We allow deadline to be set as the current block timestamp whenever this function
      // is called because this function is triggered as a follow up function (by a callback/keeper)
      // and not directly by a user/keeper. If this follow on function flow reverts due to this tx
      // being processed after a set deadline, this will cause the vault to be in a "stuck" state.
      // To resolve this, this function will have to be called again with an updated deadline until it
      // succeeds/a miner processes the tx.

      GMXManager.swapTokensForExactTokens(self, _sp);
    }

    // Adjust amount to repay for both tokens due to slight differences
    // from liqudiity withdrawal and swaps. If the amount to repay based on previous borrow
    // is more than the available balance vault has, we simply repay what the vault has
    uint256 _repayTokenAAmt;
    uint256 _repayTokenBAmt;

    if (self.depositCache.borrowParams.borrowTokenAAmt > self.tokenA.balanceOf(address(this))) {
      _repayTokenAAmt = self.tokenA.balanceOf(address(this));
    } else {
      _repayTokenAAmt = self.depositCache.borrowParams.borrowTokenAAmt;
    }

    if (self.depositCache.borrowParams.borrowTokenBAmt > self.tokenB.balanceOf(address(this))) {
      _repayTokenBAmt = self.tokenB.balanceOf(address(this));
    } else {
      _repayTokenBAmt = self.depositCache.borrowParams.borrowTokenBAmt;
    }

    // Repay borrowed assets
    GMXManager.repay(
      self,
      _repayTokenAAmt,
      _repayTokenBAmt
    );

    // Refund user the rest of the remaining withdrawn LP assets
    // Will be in tokenA/tokenB only; so if user deposited LP tokens
    // they will still be refunded in tokenA/tokenB
    self.tokenA.safeTransfer(self.depositCache.user, self.tokenA.balanceOf(address(this)));
    self.tokenB.safeTransfer(self.depositCache.user, self.tokenB.balanceOf(address(this)));

    self.status = GMXTypes.Status.Open;
  }
}
