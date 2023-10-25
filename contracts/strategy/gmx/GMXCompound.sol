// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISwap } from  "../../interfaces/swap/ISwap.sol";
import { GMXTypes } from "./GMXTypes.sol";
import { GMXChecks } from "./GMXChecks.sol";
import { GMXManager } from "./GMXManager.sol";
import { GMXReader } from "./GMXReader.sol";

/**
  * @title GMXCompound
  * @author Steadefi
  * @notice Re-usable library functions for compound operations for Steadefi leveraged vaults
*/
library GMXCompound {
  using SafeERC20 for IERC20;

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ======================== EVENTS ========================= */

  event CompoundCompleted();
  event CompoundCancelled();

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function compound(
    GMXTypes.Store storage self,
    GMXTypes.CompoundParams memory cp
  ) external {
    // Transfer any tokenA/B from trove to vault
    if (self.tokenA.balanceOf(address(self.trove)) > 0) {
      self.tokenA.safeTransferFrom(
        address(self.trove),
        address(this),
        self.tokenA.balanceOf(address(self.trove))
      );
    }
    if (self.tokenB.balanceOf(address(self.trove)) > 0) {
      self.tokenB.safeTransferFrom(
        address(self.trove),
        address(this),
        self.tokenB.balanceOf(address(self.trove))
      );
    }

    uint256 _tokenInAmt = IERC20(cp.tokenIn).balanceOf(address(this));

    // Only compound if tokenIn amount is more than 0
    if (_tokenInAmt > 0) {
      self.refundee = payable(msg.sender);

      self.compoundCache.compoundParams = cp;

      ISwap.SwapParams memory _sp;

      _sp.tokenIn = cp.tokenIn;
      _sp.tokenOut = cp.tokenOut;
      _sp.amountIn = _tokenInAmt;
      _sp.amountOut = 0; // amount out minimum calculated in Swap
      _sp.slippage = self.minSlippage;
      _sp.deadline = cp.deadline;

      GMXManager.swapExactTokensForTokens(self, _sp);

      GMXTypes.AddLiquidityParams memory _alp;

      _alp.tokenAAmt = self.tokenA.balanceOf(address(this));
      _alp.tokenBAmt = self.tokenB.balanceOf(address(this));

      self.compoundCache.depositValue = GMXReader.convertToUsdValue(
        self,
        address(self.tokenA),
        self.tokenA.balanceOf(address(this))
      )
      + GMXReader.convertToUsdValue(
        self,
        address(self.tokenB),
        self.tokenB.balanceOf(address(this))
      );

      GMXChecks.beforeCompoundChecks(self);

      self.status = GMXTypes.Status.Compound;

      _alp.minMarketTokenAmt = GMXManager.calcMinMarketSlippageAmt(
        self,
        self.compoundCache.depositValue,
        cp.slippage
      );

      _alp.executionFee = cp.executionFee;

      self.compoundCache.depositKey = GMXManager.addLiquidity(
        self,
        _alp
      );
    }
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processCompound(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessCompoundChecks(self);

    self.status = GMXTypes.Status.Open;

    emit CompoundCompleted();
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processCompoundCancellation(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessCompoundCancellationChecks(self);

    self.status = GMXTypes.Status.Compound_Failed;

    emit CompoundCancelled();
  }
}
