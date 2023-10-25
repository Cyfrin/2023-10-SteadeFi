// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IUniswapV2Router02 } from "./../MockUniswapV2/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "./../MockUniswapV2/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "./../MockUniswapV2/interfaces/IUniswapV2Factory.sol";
import { MockChainlinkOracle } from "../../MockChainlinkOracle.sol";

contract MockUniswapV2Oracle {
  /* ========== STATE VARIABLES ========== */

  // UniswapV2 factory
  IUniswapV2Factory public immutable factory;
  // UniswapV2 router
  IUniswapV2Router02 public immutable router;
  // Chainlink oracle
  MockChainlinkOracle public immutable chainlinkOracle;

  /* ========== CONSTANTS ========== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ========== CONSTRUCTOR ========== */

  /**
    * @param _factory Address of UniswapV2 factory
    * @param _router Address of UniswapV2 router
    * @param _chainlinkOracle Address of Chainlink oracle
  */
  constructor(IUniswapV2Factory _factory, IUniswapV2Router02 _router, MockChainlinkOracle _chainlinkOracle) {
    require(address(_factory) != address(0), "Invalid address");
    require(address(_router) != address(0), "Invalid address");
    require(address(_chainlinkOracle) != address(0), "Invalid address");

    factory = _factory;
    router = _router;
    chainlinkOracle = _chainlinkOracle;
  }

  /* ========== VIEW FUNCTIONS ========== */

  /**
    * Get the address of the Joe LP token for tokenA and tokenB
    * @param _tokenA Token A address
    * @param _tokenB Token B address
    * @return address Address of the Joe LP token
  */
  function lpToken(
    address _tokenA,
    address _tokenB
  ) public view returns (address) {
    return factory.getPair(_tokenA, _tokenB);
  }

  /**
    * Get token B amounts out with token A amounts in via swap liquidity pool
    * @param _amountIn Amount of token A in, expressed in token A's decimals
    * @param _tokenA Token A address
    * @param _tokenB Token B address
    * @param _pair LP token address
    * @return amountOut Amount of token B to be received, expressed in token B's decimals
  */
  function getAmountsOut(
    uint256 _amountIn,
    address _tokenA,
    address _tokenB,
    IUniswapV2Pair _pair
  ) public view returns (uint256) {
    if (_amountIn == 0) return 0;
    require(address(_pair) != address(0), "invalid pool");
    require(
      _tokenA == _pair.token0() || _tokenA == _pair.token1(),
      "invalid token in pool"
    );
    require(
      _tokenB == _pair.token0() || _tokenB == _pair.token1(),
      "invalid token in pool"
    );

    address[] memory path = new address[](2);
    path[0] = _tokenA;
    path[1] = _tokenB;

    return router.getAmountsOut(_amountIn, path)[1];
  }

  /**
    * Get token A amounts in with token B amounts out via swap liquidity pool
    * @param _amountOut Amount of token B out, expressed in token B's decimals
    * @param _tokenA Token A address
    * @param _tokenB Token B address
    * @param _pair LP token address
    * @return amountIn Amount of token A to be swapped, expressed in token B's decimals
  */
  function getAmountsIn(
    uint256 _amountOut,
    address _tokenA,
    address _tokenB,
    IUniswapV2Pair _pair
  ) public view returns (uint256) {
    if (_amountOut == 0) return 0;
    require(address(_pair) != address(0), "invalid pool");
    require(
      _tokenA == _pair.token0() || _tokenA == _pair.token1(),
      "invalid token in pool"
    );
    require(
      _tokenB == _pair.token0() || _tokenB == _pair.token1(),
      "invalid token in pool"
    );

    address[] memory path = new address[](2);
    path[0] = _tokenA;
    path[1] = _tokenB;

    return router.getAmountsIn(_amountOut, path)[0];
  }

  /**
    * Get token A and token B's respective reserves in an amount of LP token
    * @param _amount Amount of LP token, expressed in 1e18
    * @param _tokenA Token A address
    * @param _tokenB Token B address
    * @param _pair LP token address
    * @return (reserveA, reserveB) Reserve amount of Token A and B respectively, in 1e18
  */
  function getLpTokenReserves(
    uint256 _amount,
    address _tokenA,
    address _tokenB,
    IUniswapV2Pair _pair
  ) public view returns (uint256, uint256) {
    require(address(_pair) != address(0), "invalid pool");
    require(
      _tokenA == _pair.token0() || _tokenA == _pair.token1(),
      "invalid token in pool"
    );
    require(
      _tokenB == _pair.token0() || _tokenB == _pair.token1(),
      "invalid token in pool"
    );

    uint256 reserveA;
    uint256 reserveB;

    (uint256 reserve0, uint256 reserve1, ) = _pair.getReserves();
    uint256 totalSupply = _pair.totalSupply();

    if (_tokenA == _pair.token0() && _tokenB == _pair.token1()) {
      reserveA = reserve0;
      reserveB = reserve1;
    } else {
      reserveA = reserve1;
      reserveB = reserve0;
    }

    reserveA = _amount * SAFE_MULTIPLIER / totalSupply * reserveA / SAFE_MULTIPLIER;
    reserveB = _amount * SAFE_MULTIPLIER / totalSupply * reserveB / SAFE_MULTIPLIER;

    return (reserveA, reserveB);
  }

  /**
    * Get LP token fair value from amount
    * @param _amount Amount of LP token, expressed in 1e18
    * @param _tokenA Token A address
    * @param _tokenB Token B address
    * @param _pair LP token address
    * @return lpTokenValue Value of respective tokens; expressed in 1e8
  */
  function getLpTokenValue(
    uint256 _amount,
    address _tokenA,
    address _tokenB,
    IUniswapV2Pair _pair
  ) public view returns (uint256) {
    uint256 totalSupply = _pair.totalSupply();

    (uint256 totalReserveA, uint256 totalReserveB) = getLpTokenReserves(
      totalSupply,
      _tokenA,
      _tokenB,
      _pair
    );

    uint256 sqrtK = Math.sqrt((totalReserveA * totalReserveB)) * 2**112 / totalSupply;

    // convert prices from Chainlink consult which is in 1e18 to 2**112
    uint256 priceA = chainlinkOracle.consultIn18Decimals(_tokenA)
                     * 10**8 / SAFE_MULTIPLIER
                     * 2**112 / 10**(18 - IERC20Metadata(_tokenA).decimals());
    uint256 priceB = chainlinkOracle.consultIn18Decimals(_tokenB)
                     * 10**8 / SAFE_MULTIPLIER
                     * 2**112 / 10**(18 - IERC20Metadata(_tokenB).decimals());

    uint256 lpFairValue = sqrtK * 2
                          * Math.sqrt(priceA) / 2**56
                          * Math.sqrt(priceB) / 2**56; // in 1e12

    uint256 lpFairValueIn18 = lpFairValue / 2**112
                              * 10**(36 - (IERC20Metadata(_tokenA).decimals() + IERC20Metadata(_tokenB).decimals()));

    return _amount * lpFairValueIn18 / SAFE_MULTIPLIER;
  }

  /**
    * Get token A and token B's LP token amount from value
    * @param _value Value of LP token, expressed in 1e8
    * @param _tokenA Token A address
    * @param _tokenB Token B address
    * @param _pair LP token address
    * @return lpTokenAmount Amount of LP tokens; expressed in 1e18
  */
  function getLpTokenAmount(
    uint256 _value,
    address _tokenA,
    address _tokenB,
    IUniswapV2Pair _pair
  ) public view returns (uint256) {
    uint256 lpTokenValue = getLpTokenValue(
      _pair.totalSupply(),
      _tokenA,
      _tokenB,
      _pair
    );

    uint256 lpTokenAmount = _value * _pair.totalSupply() / lpTokenValue;

    return lpTokenAmount;
  }
}
