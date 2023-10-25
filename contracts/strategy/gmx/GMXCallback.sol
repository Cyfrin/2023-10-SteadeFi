// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IDeposit } from "../../interfaces/protocols/gmx/IDeposit.sol";
import { IWithdrawal } from "../../interfaces/protocols/gmx/IWithdrawal.sol";
import { IEvent } from "../../interfaces/protocols/gmx/IEvent.sol";
import { IDepositCallbackReceiver } from "../../interfaces/protocols/gmx/IDepositCallbackReceiver.sol";
import { IWithdrawalCallbackReceiver } from "../../interfaces/protocols/gmx/IWithdrawalCallbackReceiver.sol";
import { IRoleStore } from "../../interfaces/protocols/gmx/IRoleStore.sol";
import { IGMXVault } from "../../interfaces/strategy/gmx/IGMXVault.sol";
import { Errors } from "../../utils/Errors.sol";
import { GMXTypes } from "./GMXTypes.sol";

/**
  * @title GMXCallback
  * @author Steadefi
  * @notice The GMX callback handler for Steadefi leveraged vaults
*/
contract GMXCallback is IDepositCallbackReceiver, IWithdrawalCallbackReceiver {

  /* ==================== STATE VARIABLES ==================== */

  // Address of the vault this callback handler is for
  IGMXVault public vault;
  // GMX role store address
  IRoleStore public roleStore;

  /* ======================= MODIFIERS ======================= */

  // Allow only GMX controllers
  modifier onlyController() {
    if (!roleStore.hasRole(msg.sender, keccak256(abi.encode("CONTROLLER")))) {
      revert Errors.InvalidCallbackHandler();
    } else {
      _;
    }
  }

  /* ====================== CONSTRUCTOR ====================== */

  /**
    * @notice Initialize callback contract with associated vault address
    * @param _vault Address of vault
  */
  constructor (address _vault) {
    vault = IGMXVault(_vault);
    roleStore = IRoleStore(vault.store().roleStore);
  }

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice Process vault after successful deposit execution from GMX
    * @dev Callback function for GMX handler to call
    * @param depositKey bytes32 depositKey hash of deposit created
  */
  function afterDepositExecution(
    bytes32 depositKey,
    IDeposit.Props memory /* depositProps */,
    IEvent.Props memory /* eventData */
  ) external onlyController {
    GMXTypes.Store memory _store = vault.store();

    if (
      _store.status == GMXTypes.Status.Deposit &&
      _store.depositCache.depositKey == depositKey
    ) {
      vault.processDeposit();
    } else if (
      _store.status == GMXTypes.Status.Rebalance_Add &&
      _store.rebalanceCache.depositKey == depositKey
    ) {
      vault.processRebalanceAdd();
    } else if (
      _store.status == GMXTypes.Status.Compound &&
      _store.compoundCache.depositKey == depositKey
    ) {
      vault.processCompound();
    } else if (
      _store.status == GMXTypes.Status.Withdraw_Failed &&
      _store.withdrawCache.depositKey == depositKey
    ) {
      vault.processWithdrawFailureLiquidityAdded();
    } else if (_store.status == GMXTypes.Status.Resume) {
      // This if block is to catch the Deposit callback after an
      // emergencyResume() to set the vault status to Open
      vault.processEmergencyResume();
    }
  }

  /**
    * @notice Process vault after deposit cancellation from GMX
    * @dev Callback function for GMX handler to call
    * @param depositKey bytes32 depositKey hash of deposit created
  */
  function afterDepositCancellation(
    bytes32 depositKey,
    IDeposit.Props memory /* depositProps */,
    IEvent.Props memory /* eventData */
  ) external onlyController {
    GMXTypes.Store memory _store = vault.store();

    if (_store.status == GMXTypes.Status.Deposit) {
      if (_store.depositCache.depositKey == depositKey)
        vault.processDepositCancellation();
    } else if (_store.status == GMXTypes.Status.Rebalance_Add) {
      if (_store.rebalanceCache.depositKey == depositKey)
        vault.processRebalanceAddCancellation();
    } else if (_store.status == GMXTypes.Status.Compound) {
      if (_store.compoundCache.depositKey == depositKey)
        vault.processCompoundCancellation();
    } else {
      revert Errors.DepositCancellationCallback();
    }
  }

  /**
    * @notice Process vault after successful withdrawal execution from GMX
    * @dev Callback function for GMX handler to call
    * @param withdrawKey bytes32 depositKey hash of withdrawal created
  */
  function afterWithdrawalExecution(
    bytes32 withdrawKey,
    IWithdrawal.Props memory /* withdrawProps */,
    IEvent.Props memory /* eventData */
  ) external onlyController {
    GMXTypes.Store memory _store = vault.store();

    if (
      _store.status == GMXTypes.Status.Withdraw &&
      _store.withdrawCache.withdrawKey == withdrawKey
    ) {
      vault.processWithdraw();
    } else if (
      _store.status == GMXTypes.Status.Rebalance_Remove &&
      _store.rebalanceCache.withdrawKey == withdrawKey
    ) {
      vault.processRebalanceRemove();
    } else if (
      _store.status == GMXTypes.Status.Deposit_Failed &&
      _store.depositCache.withdrawKey == withdrawKey
    ) {
      vault.processDepositFailureLiquidityWithdrawal();
    }
  }

  /**
    * @notice Process vault after withdrawal cancellation from GMX
    * @dev Callback function for GMX handler to call
    * @param withdrawKey bytes32 withdrawalKey hash of withdrawal created
  */
  function afterWithdrawalCancellation(
    bytes32 withdrawKey,
    IWithdrawal.Props memory /* withdrawProps */,
    IEvent.Props memory /* eventData */
  ) external onlyController {
    GMXTypes.Store memory _store = vault.store();

    if (_store.status == GMXTypes.Status.Withdraw) {
      if (_store.withdrawCache.withdrawKey == withdrawKey)
        vault.processWithdrawCancellation();
    } else if (_store.status == GMXTypes.Status.Rebalance_Remove) {
      if (_store.rebalanceCache.withdrawKey == withdrawKey)
        vault.processRebalanceRemoveCancellation();
    } else {
      revert Errors.WithdrawalCancellationCallback();
    }
  }
}
