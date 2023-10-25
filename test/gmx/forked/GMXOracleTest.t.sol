// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import { console, console2 } from "forge-std/Test.sol";
import { TestUtils } from "../../helpers/TestUtils.sol";
import { ISyntheticReader } from "../../../contracts/interfaces/protocols/gmx/ISyntheticReader.sol";
import { IChainlinkOracle } from "../../../contracts/interfaces/oracles/IChainlinkOracle.sol";

import { GMXOracle } from "../../../contracts/oracles/GMXOracle.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";

contract GMXOracleTest is TestUtils {
  address dataStore = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
  IChainlinkOracle chainlinkOracle = IChainlinkOracle(0xb6C62D5EB1F572351CC66540d043EF53c4Cd2239);
  ISyntheticReader syntheticReader = ISyntheticReader(0xf60becbba223EEA9495Da3f606753867eC10d139);

  GMXOracle gmxOracle;

  address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
  address marketToken = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;


  function setUp() external {
    vm.createSelectFork("https://arbitrum-mainnet.infura.io/v3/9e9b198d16fa49f49b4c7078bfb0b3b5", 143387456);

    gmxOracle = new GMXOracle(dataStore, syntheticReader,  chainlinkOracle);
  }

  function test_getAmountsOut() external {
    uint256 amountOut = gmxOracle.getAmountsOut(
      marketToken,
      USDC,
      WETH,
      USDC,
      WETH,
      1e18
    );

    assertTrue(roughlyEqual(amountOut, 1800e6, 25e6), "amountOut should be roughly 1800e6");

    amountOut = gmxOracle.getAmountsOut(
      marketToken,
      USDC,
      WETH,
      USDC,
      USDC,
      1800e6
    );

    assertTrue(roughlyEqual(amountOut, 1e18, 1e17), "amountOut should be roughly 1e18");
  }

  function test_getAmountsIn() external {
    uint256 amountIn = gmxOracle.getAmountsIn(
      marketToken,
      USDC,
      WETH,
      USDC,
      USDC,
      1800e6
    );

    assertTrue(roughlyEqual(amountIn, 1e18, 1e17), "amountIn should be roughly 1e18");

    amountIn = gmxOracle.getAmountsIn(
      marketToken,
      USDC,
      WETH,
      USDC,
      WETH,
      1e18
    );

    assertTrue(roughlyEqual(amountIn, 1800e6, 25e6), "amountIn should be roughly 1800e6");
  }

  function test_getMarketTokenInfo() external {
    bytes32 _pnlFactorType = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_DEPOSITS"));

    (int256 marketTokenPrice, ISyntheticReader.MarketPoolValueInfoProps memory marketPoolValueInfo) = gmxOracle.getMarketTokenInfo(
      marketToken,
      USDC,
      WETH,
      USDC,
      _pnlFactorType,
      true
    );

    assertTrue((uint256(marketTokenPrice) > 1e30), "marketTokenPrice should be > 1e30");
    assertTrue(marketPoolValueInfo.longTokenAmount > 0, "marketPoolValueInfo.longTokenAmount should be > 0");
    assertTrue(marketPoolValueInfo.shortTokenAmount > 0, "marketPoolValueInfo.shortTokenAmount should be > 0");
  }

  function test_getLpTokenReserves() external {
    (uint256 tokenAReserve, uint256 tokenBReserve) = gmxOracle.getLpTokenReserves(
      marketToken,
      USDC,
      WETH,
      USDC
    );

    assertTrue(tokenAReserve > 0, "tokenAReserve should be > 0");
    assertTrue(tokenBReserve > 0, "tokenBReserve should be > 0");
  }

  function test_getLpTokenValue() external {
    uint256 lpTokenValue = gmxOracle.getLpTokenValue(
      marketToken,
      WETH,
      WETH,
      USDC,
      true,
      true
    );

    assertTrue(roughlyEqual(lpTokenValue, 1e18, 1e17), "lpTokenValue should be roughly 1e18");
  }
}
