// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { GMXTypes } from "./GMXTypes.sol";
import { GMXReader } from "./GMXReader.sol";
import { GMXChecks } from "./GMXChecks.sol";
import { GMXManager } from "./GMXManager.sol";

/**
  * @title GMXRebalance
  * @author Steadefi
  * @notice Re-usable library functions for rebalancing operations for Steadefi leveraged vaults
*/
library GMXRebalance {

  /* ======================== EVENTS ========================= */

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

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function rebalanceAdd(
    GMXTypes.Store storage self,
    GMXTypes.RebalanceAddParams memory rap
  ) external {
    self.refundee = payable(msg.sender);

    GMXTypes.HealthParams memory _hp;

    _hp.lpAmtBefore = GMXReader.lpAmt(self);
    _hp.debtRatioBefore = GMXReader.debtRatio(self);
    _hp.deltaBefore = GMXReader.delta(self);
    _hp.svTokenValueBefore = GMXReader.svTokenValue(self);

    GMXTypes.RebalanceCache memory _rc;

    _rc.rebalanceType = rap.rebalanceType;
    _rc.borrowParams = rap.borrowParams;
    _rc.healthParams = _hp;

    self.rebalanceCache = _rc;

    GMXChecks.beforeRebalanceChecks(self, rap.rebalanceType);

    self.status = GMXTypes.Status.Rebalance_Add;

    GMXManager.borrow(
      self,
      rap.borrowParams.borrowTokenAAmt,
      rap.borrowParams.borrowTokenBAmt
    );

    GMXTypes.AddLiquidityParams memory _alp;

    _alp.tokenAAmt = self.tokenA.balanceOf(address(this));
    _alp.tokenBAmt = self.tokenB.balanceOf(address(this));

    // Calculate deposit value after borrows and repays
    // Rebalance will only deal with tokenA and tokenB and not LP tokens
    uint256 _depositValue = GMXReader.convertToUsdValue(
      self,
      address(self.tokenA),
      self.tokenA.balanceOf(address(this))
    )
    + GMXReader.convertToUsdValue(
      self,
      address(self.tokenB),
      self.tokenB.balanceOf(address(this))
    );

    _alp.minMarketTokenAmt = GMXManager.calcMinMarketSlippageAmt(
      self,
      _depositValue,
      rap.slippage
    );

    _alp.executionFee = rap.executionFee;

    self.rebalanceCache.depositKey = GMXManager.addLiquidity(
      self,
      _alp
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processRebalanceAdd(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessRebalanceChecks(self);

    try GMXChecks.afterRebalanceChecks(self) {
      self.status = GMXTypes.Status.Open;

      emit RebalanceSuccess(
        self.rebalanceCache.healthParams.svTokenValueBefore,
        GMXReader.svTokenValue(self)
      );
    } catch (bytes memory reason) {
      self.status = GMXTypes.Status.Rebalance_Open;

      emit RebalanceOpen(
        reason,
        self.rebalanceCache.healthParams.svTokenValueBefore,
        GMXReader.svTokenValue(self)
      );
    }
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processRebalanceAddCancellation(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessRebalanceChecks(self);

    GMXManager.repay(
      self,
      self.tokenA.balanceOf(address(this)),
      self.tokenB.balanceOf(address(this))
    );

    self.status = GMXTypes.Status.Open;

    emit RebalanceCancelled();
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function rebalanceRemove(
    GMXTypes.Store storage self,
    GMXTypes.RebalanceRemoveParams memory rrp
  ) external {
    self.refundee = payable(msg.sender);

    GMXTypes.HealthParams memory _hp;

    _hp.lpAmtBefore = GMXReader.lpAmt(self);
    _hp.debtRatioBefore = GMXReader.debtRatio(self);
    _hp.deltaBefore = GMXReader.delta(self);
    _hp.svTokenValueBefore = GMXReader.svTokenValue(self);

    GMXTypes.RebalanceCache memory _rc;

    _rc.rebalanceType = rrp.rebalanceType;
    _rc.healthParams = _hp;

    self.rebalanceCache = _rc;

    GMXChecks.beforeRebalanceChecks(self, rrp.rebalanceType);

    self.status = GMXTypes.Status.Rebalance_Remove;

    GMXTypes.RemoveLiquidityParams memory _rlp;

    // When rebalancing delta, repay only tokenA so withdraw liquidity only in tokenA
    // When rebalancing debt, repay only tokenB so withdraw liquidity only in tokenA
    if (rrp.rebalanceType == GMXTypes.RebalanceType.Delta) {
      address[] memory _tokenBSwapPath = new address[](1);
      _tokenBSwapPath[0] = address(self.lpToken);
      _rlp.tokenBSwapPath = _tokenBSwapPath;

      (_rlp.minTokenAAmt, _rlp.minTokenBAmt) = GMXManager.calcMinTokensSlippageAmt(
        self,
        rrp.lpAmtToRemove,
        address(self.tokenA),
        address(self.tokenA),
        rrp.slippage
      );
    } else if (rrp.rebalanceType == GMXTypes.RebalanceType.Debt) {
      address[] memory _tokenASwapPath = new address[](1);
      _tokenASwapPath[0] = address(self.lpToken);
      _rlp.tokenASwapPath = _tokenASwapPath;

      (_rlp.minTokenAAmt, _rlp.minTokenBAmt) = GMXManager.calcMinTokensSlippageAmt(
        self,
        rrp.lpAmtToRemove,
        address(self.tokenB),
        address(self.tokenB),
        rrp.slippage
      );
    }

    _rlp.lpAmt = rrp.lpAmtToRemove;
    _rlp.executionFee = rrp.executionFee;

    self.rebalanceCache.withdrawKey = GMXManager.removeLiquidity(
      self,
      _rlp
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processRebalanceRemove(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessRebalanceChecks(self);

    GMXManager.repay(
      self,
      self.tokenA.balanceOf(address(this)),
      self.tokenB.balanceOf(address(this))
    );

    try GMXChecks.afterRebalanceChecks(self) {
      self.status = GMXTypes.Status.Open;

      emit RebalanceSuccess(
        self.rebalanceCache.healthParams.svTokenValueBefore,
        GMXReader.svTokenValue(self)
      );
    } catch (bytes memory reason) {
      self.status = GMXTypes.Status.Rebalance_Open;

      emit RebalanceOpen(
        reason,
        self.rebalanceCache.healthParams.svTokenValueBefore,
        GMXReader.svTokenValue(self)
      );
    }
  }

  /**
    * @dev Process cancellation after processRebalanceRemoveCancellation()
    * @param self Vault store data
  **/
  function processRebalanceRemoveCancellation(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessRebalanceChecks(self);

    self.status = GMXTypes.Status.Open;

    emit RebalanceCancelled();
  }
}
