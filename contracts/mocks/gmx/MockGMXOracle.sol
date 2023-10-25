// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IChainlinkOracle } from "../../interfaces/oracles/IChainlinkOracle.sol";
import { MockExchangeRouter } from "./MockExchangeRouter.sol";

import { console } from "forge-std/console.sol";

contract MockGMXOracle {
  IChainlinkOracle public chainlinkOracle;
  MockExchangeRouter public mockExchangeRouter;

  constructor(IChainlinkOracle _chainlinkOracle, MockExchangeRouter _mockExchangeRouter) {
    chainlinkOracle = _chainlinkOracle;
    mockExchangeRouter = _mockExchangeRouter;
  }

  function getLpTokenValue(
    address /*marketToken*/,
    address /* indexToken */,
    address longToken,
    address shortToken ,
    bool /* isDeposit */,
    bool /* maximize */
  ) public view returns (uint256) {
    uint256 priceIn1e30 = mockExchangeRouter.getMarketTokenInfo(
      address(0),
      address(0),
      longToken,
      shortToken,
      true,
      true
    );

    return priceIn1e30 / 1e12;
  }

  function getLpTokenReserves(
    address  marketToken,
    address /* indexToken */,
    address longToken,
    address shortToken
  ) public view returns (uint256, uint256) {
    uint256 longTokenBalance = IERC20(longToken).balanceOf(marketToken);
    uint256 shortTokenBalance = IERC20(shortToken).balanceOf(marketToken);

    return (longTokenBalance, shortTokenBalance);
  }
}
