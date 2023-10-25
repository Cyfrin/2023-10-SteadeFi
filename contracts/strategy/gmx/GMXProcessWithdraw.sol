// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwap } from  "../../interfaces/swap/ISwap.sol";
import { GMXTypes } from "./GMXTypes.sol";
import { GMXReader } from "./GMXReader.sol";
import { GMXChecks } from "./GMXChecks.sol";
import { GMXManager } from "./GMXManager.sol";

/**
  * @title GMXProcessWithdraw
  * @author Steadefi
  * @notice Re-usable library functions for process withdraw operations for Steadefi leveraged vaults
*/
library GMXProcessWithdraw {

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processWithdraw(
    GMXTypes.Store storage self
  ) external {
    // Check if swap between assets are needed for repayment
    (
      bool _swapNeeded,
      address _tokenFrom,
      address _tokenTo,
      uint256 _tokenToAmt
    ) = GMXManager.calcSwapForRepay(self, self.withdrawCache.repayParams);

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

    // Repay debt
    GMXManager.repay(
      self,
      self.withdrawCache.repayParams.repayTokenAAmt,
      self.withdrawCache.repayParams.repayTokenBAmt
    );

    // At this point, the LP has been removed for assets for repayment hence
    // equityValue should be less than before. Note that if user wants to withdraw
    // in LP token, the equityValue here should still be less than before as a portion
    // of LP will still have been withdrawn for assets for debt repayment
    self.withdrawCache.healthParams.equityAfter = GMXReader.equityValue(self);

    // If user wants to withdraw in tokenA/B, swap tokens accordingly and update tokensToUser
    // Else if user wants to withdraw in LP token, the tokensToUser is already previously
    // set in GMXWithdraw.withdraw()
    if (
      self.withdrawCache.withdrawParams.token == address(self.tokenA) ||
      self.withdrawCache.withdrawParams.token == address(self.tokenB)
    ) {
      ISwap.SwapParams memory _sp;

      if (self.withdrawCache.withdrawParams.token == address(self.tokenA)) {
        _sp.tokenIn = address(self.tokenB);
        _sp.tokenOut = address(self.tokenA);
        _sp.amountIn = self.tokenB.balanceOf(address(this));
      }

      if (self.withdrawCache.withdrawParams.token == address(self.tokenB)) {
        _sp.tokenIn = address(self.tokenA);
        _sp.tokenOut = address(self.tokenB);
        _sp.amountIn = self.tokenA.balanceOf(address(this));
      }

      _sp.slippage = self.minSlippage;
      _sp.deadline = block.timestamp;
      // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      // We allow deadline to be set as the current block timestamp whenever this function
      // is called because this function is triggered as a follow up function (by a callback/keeper)
      // and not directly by a user/keeper. If this follow on function flow reverts due to this tx
      // being processed after a set deadline, this will cause the vault to be in a "stuck" state.
      // To resolve this, this function will have to be called again with an updated deadline until it
      // succeeds/a miner processes the tx.

      GMXManager.swapExactTokensForTokens(self, _sp);

      self.withdrawCache.tokensToUser =
        IERC20(self.withdrawCache.withdrawParams.token).balanceOf(address(this));

      GMXChecks.afterWithdrawChecks(self);
    }
  }
}
