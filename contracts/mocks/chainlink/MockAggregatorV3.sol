// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MockAggregatorV3 is AggregatorV3Interface {
  string private _description;

  struct PreviousRoundData {
    uint80 roundId;
    int256 answer;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 answeredInRound;
  }

  struct CurrentRoundData{
    uint80 roundId;
    int256 answer;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 answeredInRound;
  }

  PreviousRoundData public _previousRoundData;
  CurrentRoundData public _currentRoundData;

  constructor(string memory description_) {
    _description = description_;
  }

  function setPreviousRoundData(PreviousRoundData memory _data) external {
    _previousRoundData.roundId = _data.roundId;
    _previousRoundData.answer = _data.answer;
    _previousRoundData.startedAt = _data.startedAt;
    _previousRoundData.updatedAt = _data.updatedAt;
    _previousRoundData.answeredInRound = _data.answeredInRound;
  }

  function setCurrentRoundData(CurrentRoundData memory _data) external {
    _currentRoundData.roundId = _data.roundId;
    _currentRoundData.answer = _data.answer;
    _currentRoundData.startedAt = _data.startedAt;
    _currentRoundData.updatedAt = _data.updatedAt;
    _currentRoundData.answeredInRound = _data.answeredInRound;
  }

  function decimals() external pure override returns (uint8) {
    return 8;
  }

  function description() external view override returns (string memory) {
    return _description;
  }

  function version() external pure override returns (uint256) {
    return 1;
  }

  function getRoundData(uint80 /*_roundId*/)
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    roundId = _previousRoundData.roundId;
    answer = _previousRoundData.answer;
    startedAt = _previousRoundData.startedAt;
    updatedAt = _previousRoundData.updatedAt;
    answeredInRound = _previousRoundData.answeredInRound;
  }

  function latestRoundData()
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    roundId = _currentRoundData.roundId;
    answer = _currentRoundData.answer;
    startedAt = _currentRoundData.startedAt;
    updatedAt = _currentRoundData.updatedAt;
    answeredInRound = _currentRoundData.answeredInRound;
  }
}
