// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IGMXVault } from  "../../interfaces/strategy/gmx/IGMXVault.sol";
import { GMXTypes } from  "./GMXTypes.sol";

/**
  * @title GMXTrove
  * @author Steadefi
  * @notice A temporary holding contract for reward tokens to be eventually compounded to the
  * vaultSteadefi leveraged vault. This trove is only used in the event that reward tokens are
  * given as tokenA/tokenB and periodically airdropped to the vault (instead of a claim).
  * To prevent the vault from incorrectly recoginizing the airdropped rewards to a
  * depositor/withdrawer, we sweep any balance tokenA/tokenB from the vault to this, and only
  * on compound, we transfer the tokens from this to the vault.
*/
contract GMXTrove {

  /* ==================== STATE VARIABLES ==================== */

  // Address of the vault this trove handler is for
  IGMXVault public vault;

  /* ====================== CONSTRUCTOR ====================== */

  /**
    * @notice Initialize trove contract with associated vault address
    * @param _vault Address of vault
  */
  constructor (address _vault) {
    vault = IGMXVault(_vault);

    GMXTypes.Store memory _store = vault.store();

    // Set token approvals for this trove's vault contract
    _store.tokenA.approve(address(vault), type(uint256).max);
    _store.tokenB.approve(address(vault), type(uint256).max);
  }
}
