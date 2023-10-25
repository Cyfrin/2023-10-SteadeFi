// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;


contract MockSyntheticReader {
  uint256 marketTokenPrice;

  // getMarketTokenInfo() should return price in 1e30
  function getMarketTokenInfo(
    address /* _marketToken */,
    address /* _indexToken */,
    address /* _longToken */,
    address /* _shortToken */,
    bool /* isDeposit */,
    bool /* maximise */
  ) external view returns (uint256) {
    return marketTokenPrice;
  }

  function setMarketTokenPrice(uint256 _marketTokenPrice) external {
    marketTokenPrice = _marketTokenPrice;
  }
}
