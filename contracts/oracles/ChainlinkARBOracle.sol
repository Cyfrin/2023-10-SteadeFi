// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { Errors } from "../utils/Errors.sol";

contract ChainlinkARBOracle is Ownable2Step, Pausable {
  using SafeCast for int256;

  /* ======================= STRUCTS ========================= */

  struct ChainlinkResponse {
    uint80 roundId;
    int256 answer;
    uint256 timestamp;
    bool success;
    uint8 decimals;
  }

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;
  uint256 public constant SEQUENCER_GRACE_PERIOD_TIME = 1 hours;

  /* ==================== STATE VARIABLES ==================== */

  // Chainlink Arbitrum sequencer feed address
  AggregatorV3Interface internal sequencerUptimeFeed;

  /* ======================= MAPPINGS ======================== */

  // Mapping of token to Chainlink USD price feed
  mapping(address => address) public feeds;
  // Mapping of token to maximum delay allowed (in seconds) of last price update
  mapping(address => uint256) public maxDelays;
  // Mapping of token to maximum % deviation allowed (in 1e18) of last price update
  mapping(address => uint256) public maxDeviations;

  /* ====================== CONSTRUCTOR ====================== */

  /**
    * @param sequencerFeed  Chainlink Arbitrum sequencer feed address
  */
  constructor(address sequencerFeed) Ownable(msg.sender) {
    if (sequencerFeed == address(0)) revert Errors.ZeroAddressNotAllowed();

    sequencerUptimeFeed = AggregatorV3Interface(sequencerFeed);
  }

  /* ===================== VIEW FUNCTIONS ==================== */

  /**
    * @notice Get token price from Chainlink feed
    * @param token Token address
    * @return price Asset price in int256
    * @return decimals Price decimals in uint8
  */
  function consult(address token) public view whenNotPaused returns (int256, uint8) {
    address _feed = feeds[token];

    if (_feed == address(0)) revert Errors.NoTokenPriceFeedAvailable();

    ChainlinkResponse memory chainlinkResponse = _getChainlinkResponse(_feed);
    ChainlinkResponse memory prevChainlinkResponse = _getPrevChainlinkResponse(_feed, chainlinkResponse.roundId);

    if (_chainlinkIsFrozen(chainlinkResponse, token)) revert Errors.FrozenTokenPriceFeed();
    if (_chainlinkIsBroken(chainlinkResponse, prevChainlinkResponse, token)) revert Errors.BrokenTokenPriceFeed();

    return (chainlinkResponse.answer, chainlinkResponse.decimals);
  }

  /**
    * @notice Get token price from Chainlink feed returned in 1e18
    * @param token Token address
    * @return price in 1e18
  */
  function consultIn18Decimals(address token) external view whenNotPaused returns (uint256) {
    (int256 _answer, uint8 _decimals) = consult(token);

    return _answer.toUint256() * 1e18 / (10 ** _decimals);
  }

  /* ================== INTERNAL FUNCTIONS =================== */

  /**
    * @notice Check if Chainlink oracle is not working as expected
    * @param currentResponse Current Chainlink response
    * @param prevResponse Previous Chainlink response
    * @param token Token address
    * @return Status of check in boolean
  */
  function _chainlinkIsBroken(
    ChainlinkResponse memory currentResponse,
    ChainlinkResponse memory prevResponse,
    address token
  ) internal view returns (bool) {
    return _badChainlinkResponse(currentResponse) ||
           _badChainlinkResponse(prevResponse) ||
           _badPriceDeviation(currentResponse, prevResponse, token);
  }

  /**
    * @notice Checks to see if Chainlink oracle is returning a bad response
    * @param response Chainlink response
    * @return Status of check in boolean
  */
  function _badChainlinkResponse(ChainlinkResponse memory response) internal view returns (bool) {
    // Check for response call reverted
    if (!response.success) { return true; }
    // Check for an invalid roundId that is 0
    if (response.roundId == 0) { return true; }
    // Check for an invalid timeStamp that is 0, or in the future
    if (response.timestamp == 0 || response.timestamp > block.timestamp) { return true; }
    // Check for non-positive price
    if (response.answer == 0) { return true; }

    return false;
  }

  /**
    * @notice Check to see if Chainlink oracle response is frozen/too stale
    * @param response Chainlink response
    * @param token Token address
    * @return Status of check in boolean
  */
  function _chainlinkIsFrozen(ChainlinkResponse memory response, address token) internal view returns (bool) {
    return (block.timestamp - response.timestamp) > maxDelays[token];
  }

  /**
    * @notice Check to see if Chainlink oracle current response's price price deviation
    * is too large compared to previous response's price
    * @param currentResponse Current Chainlink response
    * @param prevResponse Previous Chainlink response
    * @param token Token address
    * @return Status of check in boolean
  */
  function _badPriceDeviation(
    ChainlinkResponse memory currentResponse,
    ChainlinkResponse memory prevResponse,
    address token
  ) internal view returns (bool) {
    // Check for a deviation that is too large
    uint256 _deviation;

    if (currentResponse.answer > prevResponse.answer) {
      _deviation = uint256(currentResponse.answer - prevResponse.answer) * SAFE_MULTIPLIER / uint256(prevResponse.answer);
    } else {
      _deviation = uint256(prevResponse.answer - currentResponse.answer) * SAFE_MULTIPLIER / uint256(prevResponse.answer);
    }

    return _deviation > maxDeviations[token];
  }

  /**
    * @notice Get latest Chainlink response
    * @param _feed Chainlink oracle feed address
    * @return ChainlinkResponse
  */
  function _getChainlinkResponse(address _feed) internal view returns (ChainlinkResponse memory) {
    ChainlinkResponse memory _chainlinkResponse;

    _chainlinkResponse.decimals = AggregatorV3Interface(_feed).decimals();

    // Arbitrum sequencer uptime feed
    (
      /* uint80 _roundID*/,
      int256 _answer,
      uint256 _startedAt,
      /* uint256 _updatedAt */,
      /* uint80 _answeredInRound */
    ) = sequencerUptimeFeed.latestRoundData();

    // Answer == 0: Sequencer is up
    // Answer == 1: Sequencer is down
    bool _isSequencerUp = _answer == 0;
    if (!_isSequencerUp) revert Errors.SequencerDown();

    // Make sure the grace period has passed after the
    // sequencer is back up.
    uint256 _timeSinceUp = block.timestamp - _startedAt;
    if (_timeSinceUp <= SEQUENCER_GRACE_PERIOD_TIME) revert Errors.GracePeriodNotOver();

    (
      uint80 _latestRoundId,
      int256 _latestAnswer,
      /* uint256 _startedAt */,
      uint256 _latestTimestamp,
      /* uint80 _answeredInRound */
    ) = AggregatorV3Interface(_feed).latestRoundData();

    _chainlinkResponse.roundId = _latestRoundId;
    _chainlinkResponse.answer = _latestAnswer;
    _chainlinkResponse.timestamp = _latestTimestamp;
    _chainlinkResponse.success = true;

    return _chainlinkResponse;
  }

  /**
    * @notice Get previous round's Chainlink response from current round
    * @param _feed Chainlink oracle feed address
    * @param _currentRoundId Current roundId from current Chainlink response
    * @return ChainlinkResponse
  */
  function _getPrevChainlinkResponse(address _feed, uint80 _currentRoundId) internal view returns (ChainlinkResponse memory) {
    ChainlinkResponse memory _prevChainlinkResponse;

    (
      uint80 _roundId,
      int256 _answer,
      /* uint256 _startedAt */,
      uint256 _timestamp,
      /* uint80 _answeredInRound */
    ) = AggregatorV3Interface(_feed).getRoundData(_currentRoundId - 1);

    _prevChainlinkResponse.roundId = _roundId;
    _prevChainlinkResponse.answer = _answer;
    _prevChainlinkResponse.timestamp = _timestamp;
    _prevChainlinkResponse.success = true;

    return _prevChainlinkResponse;
  }

  /* ================= RESTRICTED FUNCTIONS ================== */

  /**
    * @notice Add Chainlink price feed for token
    * @param token Token address
    * @param feed Chainlink price feed address
  */
  function addTokenPriceFeed(address token, address feed) external onlyOwner {
    if (token == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (feed == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (feeds[token] != address(0)) revert Errors.TokenPriceFeedAlreadySet();

    feeds[token] = feed;
  }

  /**
    * @notice Add Chainlink max delay for token
    * @param token Token address
    * @param maxDelay  Max delay allowed in seconds
  */
  function addTokenMaxDelay(address token, uint256 maxDelay) external onlyOwner {
    if (token == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (feeds[token] == address(0)) revert Errors.NoTokenPriceFeedAvailable();
    if (maxDelay < 0) revert Errors.TokenPriceFeedMaxDelayMustBeGreaterOrEqualToZero();

    maxDelays[token] = maxDelay;
  }

  /**
    * @notice Add Chainlink max deviation for token
    * @param token Token address
    * @param maxDeviation  Max deviation allowed in seconds
  */
  function addTokenMaxDeviation(address token, uint256 maxDeviation) external onlyOwner {
    if (token == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (feeds[token] == address(0)) revert Errors.NoTokenPriceFeedAvailable();
    if (maxDeviation < 0) revert Errors.TokenPriceFeedMaxDeviationMustBeGreaterOrEqualToZero();

    maxDeviations[token] = maxDeviation;
  }

  /**
    * @notice Emergency pause of this oracle
  */
  function emergencyPause() external onlyOwner whenNotPaused {
    _pause();
  }

  /**
    * @notice Emergency resume of this oracle
  */
  function emergencyResume() external onlyOwner whenPaused {
    _unpause();
  }
}
