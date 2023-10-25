// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol"; // TEMP
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ISyntheticReader } from "../interfaces/protocols/gmx/ISyntheticReader.sol";
import { IChainlinkOracle } from "../interfaces/oracles/IChainlinkOracle.sol";
import { Errors } from "../utils/Errors.sol";

contract MockGMXOracleWithAdjusts is Ownable {

  /* ========== MOCK ADJUSTMENT VARIABLES FOR TESTING ========== */

  uint256 public longTokenWeightAdjust = 10000;
  uint256 public lpTokenPriceAdjust = 10000;

  function changeAdjust(
    uint256 _longTokenWeightAdjust,
    uint256 _lpTokenPriceAdjust
  ) external onlyOwner {
    longTokenWeightAdjust = _longTokenWeightAdjust;
    lpTokenPriceAdjust = _lpTokenPriceAdjust;
  }

  /* ==================== STATE VARIABLES ==================== */

  // GMX DataStore
  address public immutable dataStore;
  // GMX Synthetic Reader
  ISyntheticReader public immutable syntheticReader;
  // Chainlink oracle
  IChainlinkOracle public immutable chainlinkOracle;

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ====================== CONSTRUCTOR ====================== */

  /**
    * @param newDataStore Address of GMX DataStore
    * @param newSyntheticReader Address of GMX Synthetic Reader
    * @param newChainlinkOracle Address of Chainlink oracle
  */
  constructor(
    address newDataStore,
    ISyntheticReader newSyntheticReader,
    IChainlinkOracle newChainlinkOracle
  ) Ownable(msg.sender) {
    if (newDataStore == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (address(newSyntheticReader) == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (address(newChainlinkOracle) == address(0)) revert Errors.ZeroAddressNotAllowed();

    dataStore = newDataStore;
    syntheticReader = newSyntheticReader;
    chainlinkOracle = newChainlinkOracle;
  }

  /* ===================== VIEW FUNCTIONS ==================== */

  /**
    * @dev Get amountsOut of either the long or short token based on the amountsIn
    * of either long or short token in the market
    * @param marketToken LP token address
    * @param indexToken Index token address
    * @param longToken Long token address
    * @param shortToken Short token address
    * @param tokenIn TokenIn address
    * @param amountIn Amount of tokenIn, expressed in tokenIn's decimals
    * @return amountsOut Amount of tokenOut within LP (market) to be received, expressed in tokenOut's decimals
  */
  function getAmountsOut(
    address marketToken,
    address indexToken,
    address longToken,
    address shortToken,
    address tokenIn,
    uint256 amountIn
  ) public view returns (uint256) {
    ISyntheticReader.MarketProps memory _market;
    _market.marketToken = marketToken;
    _market.indexToken = indexToken;
    _market.longToken = longToken;
    _market.shortToken = shortToken;

    ISyntheticReader.PriceProps memory _indexTokenPrice;
    _indexTokenPrice.min = _getTokenPriceMinMaxFormatted(indexToken);
    _indexTokenPrice.max = _getTokenPriceMinMaxFormatted(indexToken);

    ISyntheticReader.PriceProps memory _longTokenPrice;
    _longTokenPrice.min = _getTokenPriceMinMaxFormatted(longToken);
    _longTokenPrice.max = _getTokenPriceMinMaxFormatted(longToken);

    ISyntheticReader.PriceProps memory _shortTokenPrice;
    _shortTokenPrice.min = _getTokenPriceMinMaxFormatted(shortToken);
    _shortTokenPrice.max = _getTokenPriceMinMaxFormatted(shortToken);

    ISyntheticReader.MarketPrices memory _prices;
    _prices.indexTokenPrice = _indexTokenPrice;
    _prices.longTokenPrice = _longTokenPrice;
    _prices.shortTokenPrice = _shortTokenPrice;

    address _uiFeeReceiver = address(0);

    (uint256 _amountsOut,,) = syntheticReader.getSwapAmountOut(
      dataStore,
      _market,
      _prices,
      tokenIn,
      amountIn,
      _uiFeeReceiver
    );

    return _amountsOut;
  }

  /**
    * @dev Helper function to calculate amountIn of either long or short token for swapping for
    * desired amountsOut of long or short token
    * @notice We utilise GMX's getSwapAmountOut() with tokenOut being tokenIn, multiplying
    * the amountsOut value by 1.0015x to account for fees and normal chainlink price feed differential
    * @param marketToken LP token address
    * @param indexToken Index token address
    * @param longToken Long token address
    * @param shortToken Short token address
    * @param tokenOut TokenIn address
    * @param amountsOut Amount of tokenIn, expressed in tokenIn's decimals
    * @return amountsOut Amount of tokenOut within LP (market) to be received, expressed in tokenOut's decimals
  */
  function getAmountsIn(
    address marketToken,
    address indexToken,
    address longToken,
    address shortToken,
    address tokenOut,
    uint256 amountsOut
  ) public view returns (uint256) {
    return getAmountsOut(
      marketToken,
      indexToken,
      longToken,
      shortToken,
      tokenOut,
      amountsOut
    ) * (1e18 + 15e14) / SAFE_MULTIPLIER;
  }

  /**
    * @dev Get LP (market) token info
    * @param marketToken LP token address
    * @param indexToken Index token address
    * @param longToken Long token address
    * @param shortToken Short token address
    * @param pnlFactorType P&L Factory type in bytes32 hashed string
    * @param maximize Min/max price boolean
    * @return (marketTokenPrice, MarketPoolValueInfoProps MarketInfo)
  */
  function getMarketTokenInfo(
    address marketToken,
    address indexToken,
    address longToken,
    address shortToken,
    bytes32 pnlFactorType,
    bool maximize
  ) public view returns (int256, ISyntheticReader.MarketPoolValueInfoProps memory) {
    if (address(marketToken) == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (address(indexToken) == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (address(longToken) == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (address(shortToken) == address(0)) revert Errors.ZeroAddressNotAllowed();

    ISyntheticReader.MarketProps memory _market;
    _market.marketToken = marketToken;
    _market.indexToken = indexToken;
    _market.longToken = longToken;
    _market.shortToken = shortToken;

    ISyntheticReader.PriceProps memory _indexTokenPrice;
    _indexTokenPrice.min = _getTokenPriceMinMaxFormatted(indexToken);
    _indexTokenPrice.max = _getTokenPriceMinMaxFormatted(indexToken);

    ISyntheticReader.PriceProps memory _longTokenPrice;
    _longTokenPrice.min = _getTokenPriceMinMaxFormatted(longToken);
    _longTokenPrice.max = _getTokenPriceMinMaxFormatted(longToken);

    ISyntheticReader.PriceProps memory _shortTokenPrice;
    _shortTokenPrice.min = _getTokenPriceMinMaxFormatted(shortToken);
    _shortTokenPrice.max = _getTokenPriceMinMaxFormatted(shortToken);

    return syntheticReader.getMarketTokenPrice(
      dataStore,
      _market,
      _indexTokenPrice,
      _longTokenPrice,
      _shortTokenPrice,
      pnlFactorType,
      maximize
    );

    // return (_marketTokenPrice, _marketInfo);
  }

  /**
    * @dev Get LP (market) token reserves
    * @param marketToken LP token address
    * @param indexToken Index token address
    * @param longToken Long token address
    * @param shortToken Short token address
    * @return (reserveA, reserveB) Reserve amount of longToken and shortToken respectively
  */
  function getLpTokenReserves(
    address marketToken,
    address indexToken,
    address longToken,
    address shortToken
  ) public view returns (uint256, uint256) {
    // _pnlFactorType value does not matter in getting token reserves
    bytes32 _pnlFactorType = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_DEPOSITS"));
    // _maximize value does not matter in getting token reserves
    bool _maximize = false;

    (, ISyntheticReader.MarketPoolValueInfoProps memory _marketInfo) = getMarketTokenInfo(
      marketToken,
      indexToken,
      longToken,
      shortToken,
      _pnlFactorType,
      _maximize
    );

    return (
      _marketInfo.longTokenAmount * longTokenWeightAdjust / 10000, // TEMP
      // _marketInfo.longTokenAmount,
      _marketInfo.shortTokenAmount
    );
  }

  /**
    * @dev Get LP (market) token reserves
    * @param marketToken LP token address
    * @param indexToken Index token address
    * @param longToken Long token address
    * @param shortToken Short token address
    * @param isDeposit Boolean for deposit or withdrawal
    * @param maximize Boolean for minimum or maximum price
    * @return marketTokenPrice in 1e18
  */
  function getLpTokenValue(
    address marketToken,
    address indexToken,
    address longToken,
    address shortToken,
    bool isDeposit,
    bool maximize
  ) public view returns (uint256) {
    bytes32 _pnlFactorType;

    if (isDeposit) {
      _pnlFactorType = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_DEPOSITS"));
    } else {
      _pnlFactorType = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_WITHDRAWALS"));
    }

    (int256 _marketTokenPrice,) = getMarketTokenInfo(
      marketToken,
      indexToken,
      longToken,
      shortToken,
      _pnlFactorType,
      maximize
    );

    // If LP token value is negative, return 0
    if (_marketTokenPrice < 0) {
      return 0;
    } else {
      // Price returned in 1e30, we normalize it to 1e12
      // return uint256(_marketTokenPrice) / 1e12;
      return uint256(_marketTokenPrice) * lpTokenPriceAdjust / 10000 / 1e12;
    }
  }


  /**
    * @dev Get token A and token B's LP token amount required for a given value
    * Used in keeper script to calculate how much LP tokens for given USD value
    * @param givenValue Given value needed, expressed in 1e30
    * @param marketToken LP token address
    * @param indexToken Index token address
    * @param longToken Long token address
    * @param shortToken Short token address
    * @param isDeposit Boolean for deposit or withdrawal
    * @param maximize Boolean for minimum or maximum price
    * @return lpTokenAmount Amount of LP tokens; expressed in 1e18
  */
  function getLpTokenAmount(
    uint256 givenValue,
    address marketToken,
    address indexToken,
    address longToken,
    address shortToken,
    bool isDeposit,
    bool maximize
  ) public view returns (uint256) {
    uint256 _lpTokenValue = getLpTokenValue(
      marketToken,
      indexToken,
      longToken,
      shortToken,
      isDeposit,
      maximize
    );

    return givenValue * SAFE_MULTIPLIER / _lpTokenValue;
  }

  /* ================== INTERNAL FUNCTIONS =================== */

  /**
    * @dev Get token price formatted for GMX mix/max decimals for 1e30 normalization
    * @param token Token address
    * @return tokenPriceMinMaxFormatted in either in 1e12 (if token decimals 18) or 1e24 (if token decimals 6)
  */
  function _getTokenPriceMinMaxFormatted(address token) internal view returns (uint256) {
    uint256 _tokenPriceMinMaxFormatted;

    if (IERC20Metadata(token).decimals() == 18) {
      _tokenPriceMinMaxFormatted = chainlinkOracle.consultIn18Decimals(token) / 1e6;
    } else if (IERC20Metadata(token).decimals() == 6) {
      _tokenPriceMinMaxFormatted = chainlinkOracle.consultIn18Decimals(token) * 1e6;
    }

    return _tokenPriceMinMaxFormatted;
  }
}
