// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { GMXTypes } from "./GMXTypes.sol";

/**
  * @title GMXReader
  * @author Steadefi
  * @notice Re-usable library functions for reading data and values for Steadefi leveraged vaults
*/
library GMXReader {
  using SafeCast for uint256;

  /* =================== CONSTANTS FUNCTIONS ================= */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ===================== VIEW FUNCTIONS ==================== */

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function svTokenValue(GMXTypes.Store storage self) public view returns (uint256) {
    uint256 equityValue_ = equityValue(self);
    uint256 totalSupply_ = IERC20(address(self.vault)).totalSupply();
    if (equityValue_ == 0 || totalSupply_ == 0) return SAFE_MULTIPLIER;
    return equityValue_ * SAFE_MULTIPLIER / totalSupply_;
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function pendingFee(GMXTypes.Store storage self) public view returns (uint256) {
    uint256 totalSupply_ = IERC20(address(self.vault)).totalSupply();
    uint256 _secondsFromLastCollection = block.timestamp - self.lastFeeCollected;
    return (totalSupply_ * self.feePerSecond * _secondsFromLastCollection) / SAFE_MULTIPLIER;
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function valueToShares(
    GMXTypes.Store storage self,
    uint256 value,
    uint256 currentEquity
  ) public view returns (uint256) {
    uint256 _sharesSupply = IERC20(address(self.vault)).totalSupply() + pendingFee(self);
    if (_sharesSupply == 0 || currentEquity == 0) return value;
    return value * _sharesSupply / currentEquity;
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function convertToUsdValue(
    GMXTypes.Store storage self,
    address token,
    uint256 amt
  ) public view returns (uint256) {
    return amt * 10**(18 - IERC20Metadata(token).decimals())
                * self.chainlinkOracle.consultIn18Decimals(token)
                / SAFE_MULTIPLIER;
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function tokenWeights(GMXTypes.Store storage self) public view returns (uint256, uint256) {
    // Get amounts of tokenA and tokenB in liquidity pool in token decimals
    (uint256 _reserveA, uint256 _reserveB) = self.gmxOracle.getLpTokenReserves(
      address(self.lpToken),
      address(self.tokenA),
      address(self.tokenA),
      address(self.tokenB)
    );

    // Get value of tokenA and tokenB in 1e18
    uint256 _tokenAValue = convertToUsdValue(self, address(self.tokenA), _reserveA);
    uint256 _tokenBValue = convertToUsdValue(self, address(self.tokenB), _reserveB);

    uint256 _totalLpValue = _tokenAValue + _tokenBValue;

    return (
      _tokenAValue * SAFE_MULTIPLIER / _totalLpValue,
      _tokenBValue * SAFE_MULTIPLIER / _totalLpValue
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function assetValue(GMXTypes.Store storage self) public view returns (uint256) {
    return lpAmt(self) * self.gmxOracle.getLpTokenValue(
      address(self.lpToken),
      address(self.tokenA),
      address(self.tokenA),
      address(self.tokenB),
      false,
      false
    ) / SAFE_MULTIPLIER;
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function debtValue(GMXTypes.Store storage self) public view returns (uint256, uint256) {
    (uint256 _tokenADebtAmt, uint256 _tokenBDebtAmt) = debtAmt(self);
    return (
      convertToUsdValue(self, address(self.tokenA), _tokenADebtAmt),
      convertToUsdValue(self, address(self.tokenB), _tokenBDebtAmt)
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function equityValue(GMXTypes.Store storage self) public view returns (uint256) {
    (uint256 _tokenADebtAmt, uint256 _tokenBDebtAmt) = debtAmt(self);

    uint256 assetValue_ = assetValue(self);

    uint256 _debtValue = convertToUsdValue(self, address(self.tokenA), _tokenADebtAmt)
                         + convertToUsdValue(self, address(self.tokenB), _tokenBDebtAmt);

    // in underflow condition return 0
    unchecked {
      if (assetValue_ < _debtValue) return 0;

      return assetValue_ - _debtValue;
    }
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function assetAmt(GMXTypes.Store storage self) public view returns (uint256, uint256) {
    (uint256 _reserveA, uint256 _reserveB) = self.gmxOracle.getLpTokenReserves(
      address(self.lpToken),
      address(self.tokenA),
      address(self.tokenA),
      address(self.tokenB)
    );

    return (
      _reserveA * SAFE_MULTIPLIER * lpAmt(self) / self.lpToken.totalSupply() / SAFE_MULTIPLIER,
      _reserveB * SAFE_MULTIPLIER * lpAmt(self) / self.lpToken.totalSupply() / SAFE_MULTIPLIER
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function debtAmt(GMXTypes.Store storage self) public view returns (uint256, uint256) {
    return (
      self.tokenALendingVault.maxRepay(address(self.vault)),
      self.tokenBLendingVault.maxRepay(address(self.vault))
    );
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function lpAmt(GMXTypes.Store storage self) public view returns (uint256) {
    return self.lpToken.balanceOf(address(self.vault));
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function leverage(GMXTypes.Store storage self) public view returns (uint256) {
    if (assetValue(self) == 0 || equityValue(self) == 0) return 0;
    return assetValue(self) * SAFE_MULTIPLIER / equityValue(self);
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function delta(GMXTypes.Store storage self) public view returns (int256) {
    (uint256 _tokenAAmt,) = assetAmt(self);
    (uint256 _tokenADebtAmt,) = debtAmt(self);
    uint256 equityValue_ = equityValue(self);

    if (_tokenAAmt == 0 && _tokenADebtAmt == 0) return 0;
    if (equityValue_ == 0) return 0;

    bool _isPositive = _tokenAAmt >= _tokenADebtAmt;

    uint256 _unsignedDelta = _isPositive ?
      _tokenAAmt - _tokenADebtAmt :
      _tokenADebtAmt - _tokenAAmt;

    int256 signedDelta = (_unsignedDelta
      * self.chainlinkOracle.consultIn18Decimals(address(self.tokenA))
      / equityValue_).toInt256();

    if (_isPositive) return signedDelta;
    else return -signedDelta;
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function debtRatio(GMXTypes.Store storage self) public view returns (uint256) {
    (uint256 _tokenADebtValue, uint256 _tokenBDebtValue) = debtValue(self);
    if (assetValue(self) == 0) return 0;
    return (_tokenADebtValue + _tokenBDebtValue) * SAFE_MULTIPLIER / assetValue(self);
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function additionalCapacity(GMXTypes.Store storage self) public view returns (uint256) {
    uint256 _additionalCapacity;

    // Long strategy only borrows short token (typically stablecoin)
    if (self.delta == GMXTypes.Delta.Long) {
      _additionalCapacity = convertToUsdValue(
        self,
        address(self.tokenB),
        self.tokenBLendingVault.totalAvailableAsset()
      ) * SAFE_MULTIPLIER / (self.leverage - 1e18);
    }

    // Neutral strategy borrows both long (typical volatile) and short token (typically stablecoin)
    // Amount of long token to borrow is equivalent to deposited value x leverage x longTokenWeight
    // Amount of short token to borrow is remaining borrow value AFTER borrowing long token
    // ---------------------------------------------------------------------------------------------
    // E.g: 3x Neutral ETH-USDC with weight of ETH being 55%, USDC 45%
    // A $1 equity deposit should result in a $2 borrow for a total of $3 assets
    // Amount of ETH to borrow would be $3 x 55% = $1.65 worth of ETH
    // Amount of USDC to borrow would be $3 (asset) - $1.65 (ETH borrowed) - $1 (equity) = $0.35
    // ---------------------------------------------------------------------------------------------
    // Note that for Neutral strategies, vault's leverage has to be 3x and above.
    // A 2x leverage neutral strategy may not work to correctly to borrow enough long token to hedge
    // while still adhering to the correct leverage factor.
    if (self.delta == GMXTypes.Delta.Neutral) {
      (uint256 _tokenAWeight, ) = tokenWeights(self);

      uint256 _maxTokenALending = convertToUsdValue(
        self,
        address(self.tokenA),
        self.tokenALendingVault.totalAvailableAsset()
      ) * SAFE_MULTIPLIER
        / (self.leverage * _tokenAWeight / SAFE_MULTIPLIER);

      uint256 _maxTokenBLending = convertToUsdValue(
        self,
        address(self.tokenB),
        self.tokenBLendingVault.totalAvailableAsset()
      ) * SAFE_MULTIPLIER
        / (self.leverage * _tokenAWeight / SAFE_MULTIPLIER)
        - 1e18;

      _additionalCapacity = _maxTokenALending > _maxTokenBLending ? _maxTokenBLending : _maxTokenALending;
    }

    return _additionalCapacity;
  }

  /**
    * @notice @inheritdoc GMXVault
    * @param self GMXTypes.Store
  */
  function capacity(GMXTypes.Store storage self) public view returns (uint256) {
    return additionalCapacity(self) + equityValue(self);
  }
}
