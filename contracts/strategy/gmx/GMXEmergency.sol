// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISwap } from  "../../interfaces/swap/ISwap.sol";
import { GMXTypes } from "./GMXTypes.sol";
import { GMXChecks } from "./GMXChecks.sol";
import { GMXManager } from "./GMXManager.sol";

/**
  * @title GMXEmergency
  * @author Steadefi
  * @notice Re-usable library functions for emergency operations for Steadefi leveraged vaults
*/
library GMXEmergency {
  using SafeERC20 for IERC20;

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;
  uint256 public constant DUST_AMOUNT = 1e17;

  /* ======================== EVENTS ========================= */

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

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function emergencyPause(
    GMXTypes.Store storage self
  ) external {
    self.refundee = payable(msg.sender);

    GMXTypes.RemoveLiquidityParams memory _rlp;

    // Remove all of the vault's LP tokens
    _rlp.lpAmt = self.lpToken.balanceOf(address(this));
    _rlp.executionFee = msg.value;

    GMXManager.removeLiquidity(
      self,
      _rlp
    );

    self.status = GMXTypes.Status.Paused;

    emit EmergencyPause();
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function emergencyResume(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeEmergencyResumeChecks(self);

    self.status = GMXTypes.Status.Resume;

    self.refundee = payable(msg.sender);

    GMXTypes.AddLiquidityParams memory _alp;

    _alp.tokenAAmt = self.tokenA.balanceOf(address(this));
    _alp.tokenBAmt = self.tokenB.balanceOf(address(this));
    _alp.executionFee = msg.value;

    GMXManager.addLiquidity(
      self,
      _alp
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function processEmergencyResume(
    GMXTypes.Store storage self
  ) external {
    GMXChecks.beforeProcessEmergencyResumeChecks(self);

    self.status = GMXTypes.Status.Open;

    emit EmergencyResume();
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function emergencyClose(
    GMXTypes.Store storage self,
    uint256 deadline
  ) external {
    GMXChecks.beforeEmergencyCloseChecks(self);

    // Repay all borrowed assets; 1e18 == 100% shareRatio to repay
    GMXTypes.RepayParams memory _rp;
    (
      _rp.repayTokenAAmt,
      _rp.repayTokenBAmt
    ) = GMXManager.calcRepay(self, 1e18);

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
      _sp.deadline = deadline;

      GMXManager.swapTokensForExactTokens(self, _sp);
    }

    GMXManager.repay(
      self,
      _rp.repayTokenAAmt,
      _rp.repayTokenBAmt
    );

    self.status = GMXTypes.Status.Closed;

    emit EmergencyClose(
      _rp.repayTokenAAmt,
      _rp.repayTokenBAmt
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function emergencyWithdraw(
    GMXTypes.Store storage self,
    uint256 shareAmt
  ) external {
    // check to ensure shares withdrawn does not exceed user's balance
    uint256 _userShareBalance = IERC20(address(self.vault)).balanceOf(msg.sender);

    // to avoid leaving dust behind
    unchecked {
      if (_userShareBalance - shareAmt < DUST_AMOUNT) {
        shareAmt = _userShareBalance;
      }
    }

    GMXChecks.beforeEmergencyWithdrawChecks(self, shareAmt);

    // share ratio calculation must be before burn()
    uint256 _shareRatio = shareAmt * SAFE_MULTIPLIER
                          / IERC20(address(self.vault)).totalSupply();

    self.vault.burn(msg.sender, shareAmt);

    uint256 _withdrawAmtTokenA = _shareRatio
                                 * self.tokenA.balanceOf(address(this))
                                 / SAFE_MULTIPLIER;
    uint256 _withdrawAmtTokenB = _shareRatio
                                 * self.tokenB.balanceOf(address(this))
                                 / SAFE_MULTIPLIER;

    self.tokenA.safeTransfer(msg.sender, _withdrawAmtTokenA);
    self.tokenB.safeTransfer(msg.sender, _withdrawAmtTokenB);

    emit EmergencyWithdraw(
      msg.sender,
      shareAmt,
      address(self.tokenA),
      _withdrawAmtTokenA,
      address(self.tokenB),
      _withdrawAmtTokenB
    );
  }
}
