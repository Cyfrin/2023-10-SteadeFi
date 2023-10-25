// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { GMXTypes } from "./GMXTypes.sol";
import { GMXReader } from "./GMXReader.sol";
import { GMXChecks } from "./GMXChecks.sol";

/**
  * @title GMXProcessDeposit
  * @author Steadefi
  * @notice Re-usable library functions for process deposit operations for Steadefi leveraged vaults
*/
library GMXProcessDeposit {

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processDeposit(
    GMXTypes.Store storage self
  ) external {
    self.depositCache.healthParams.equityAfter = GMXReader.equityValue(self);

    self.depositCache.sharesToUser = GMXReader.valueToShares(
      self,
      self.depositCache.healthParams.equityAfter - self.depositCache.healthParams.equityBefore,
      self.depositCache.healthParams.equityBefore
    );

    GMXChecks.afterDepositChecks(self);
  }
}
