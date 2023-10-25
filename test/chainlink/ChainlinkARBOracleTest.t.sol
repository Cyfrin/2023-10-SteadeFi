// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { InvariantTest } from "forge-std/InvariantTest.sol";
import { TestUtils } from "../helpers/TestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ChainlinkARBOracle } from "../../contracts/oracles/ChainlinkARBOracle.sol";
import { IChainlinkOracle } from "../../contracts/interfaces/oracles/IChainlinkOracle.sol";
import { MockAggregatorV3 } from "../../contracts/mocks/chainlink/MockAggregatorV3.sol";

contract ChainlinkARBOracleTest is Test, InvariantTest, TestUtils {
  uint256 constant SAFE_MULTIPLIER = 1e18;
  uint256 public constant SEQUENCER_GRACE_PERIOD_TIME = 1 hours;

  address payable owner;
  address payable user1;

  address _USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
  address _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

  ChainlinkARBOracle chainlinkOracle;
  MockAggregatorV3 mockWETHPriceFeed;
  MockAggregatorV3 mockUSDCPriceFeed;
  MockAggregatorV3 mockSequencerUptimeFeed;
  MockAggregatorV3.PreviousRoundData previousRoundData;
  MockAggregatorV3.CurrentRoundData currentRoundData;
  MockAggregatorV3.CurrentRoundData sequencerRoundData;

  function setUp() public {
    // vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 139268246);

    owner = payable(makeAddr("Owner"));
    user1 = payable(makeAddr("User1"));

    vm.startPrank(owner);
    vm.warp(1632934800);

    mockWETHPriceFeed = new MockAggregatorV3("Mock WETH Price Feed");
    mockUSDCPriceFeed = new MockAggregatorV3("Mock USDC Price Feed");
    mockSequencerUptimeFeed = new MockAggregatorV3("Mock Sequencer Uptime Feed");

    chainlinkOracle = new ChainlinkARBOracle(address(mockSequencerUptimeFeed));

    // set sequencer uptime feed
    currentRoundData.answer = 0;
    currentRoundData.startedAt = block.timestamp - 2 days;
    mockSequencerUptimeFeed.setCurrentRoundData(currentRoundData);

    // add token price feeds
    chainlinkOracle.addTokenPriceFeed(_WETH, address(mockWETHPriceFeed));
    chainlinkOracle.addTokenPriceFeed(_USDC, address(mockUSDCPriceFeed));

    // set price feeds
    previousRoundData.roundId = 1;
    previousRoundData.answer = 1600e8;
    previousRoundData.startedAt = 1632931200;
    previousRoundData.updatedAt = 1632931200;
    previousRoundData.answeredInRound = 1;
    mockWETHPriceFeed.setPreviousRoundData(previousRoundData);

    currentRoundData.roundId = 2;
    currentRoundData.answer = 15888e7;
    currentRoundData.startedAt = 1632934800;
    currentRoundData.updatedAt = 1632934800;
    currentRoundData.answeredInRound = 2;
    mockWETHPriceFeed.setCurrentRoundData(currentRoundData);

    sequencerRoundData.answer = 0;
    sequencerRoundData.startedAt = block.timestamp;

    // add token max delay
    chainlinkOracle.addTokenMaxDelay(_WETH, 86400);
    chainlinkOracle.addTokenMaxDelay(_USDC, 86400);

    // add max deviation
    chainlinkOracle.addTokenMaxDeviation(_WETH, 0.5e18);
    chainlinkOracle.addTokenMaxDeviation(_USDC, 0.1e18);
  }

  function test_consult() external {
    vm.startPrank(user1);

    uint256 id = vm.snapshot();

    expectRevert("NoTokenPriceFeedAvailable()");
    chainlinkOracle.consult(address(0));

    sequencerRoundData.answer = 1;
    mockSequencerUptimeFeed.setCurrentRoundData(sequencerRoundData);
    expectRevert("SequencerDown()");
    chainlinkOracle.consult(_WETH);

    vm.revertTo(id);

    sequencerRoundData.answer = 0;
    sequencerRoundData.startedAt = block.timestamp - 1 hours;
    mockSequencerUptimeFeed.setCurrentRoundData(sequencerRoundData);
    expectRevert("GracePeriodNotOver()");
    chainlinkOracle.consult(_WETH);

    vm.revertTo(id);

    currentRoundData.updatedAt = 1632934800 - 86401;
    mockWETHPriceFeed.setCurrentRoundData(currentRoundData);
    expectRevert("FrozenTokenPriceFeed()");
    chainlinkOracle.consult(_WETH);

    vm.revertTo(id);

    currentRoundData.answer = 0;
    mockWETHPriceFeed.setCurrentRoundData(currentRoundData);
    // @note unable to test other scenarios of broken price feed due arthimetic underflow
    expectRevert("BrokenTokenPriceFeed()");
    chainlinkOracle.consult(_WETH);

    vm.revertTo(id);

    (int256 answer, uint8 decimals) = chainlinkOracle.consult(_WETH);
    assertEq(answer, 15888e7, "wrong answer");
    assertEq(decimals, 8, "wrong decimals");
  }

  function test_consultIn18Decimals() external {
    vm.startPrank(user1);

    uint256 ans = chainlinkOracle.consultIn18Decimals(_WETH);
    assertEq(ans, 15888e17, "wrong answer");
  }

  function test_emergencyPause() external {
    vm.startPrank(owner);

    chainlinkOracle.emergencyPause();
    assertTrue(chainlinkOracle.paused(), "oracle should be paused");
  }

  function test_emergencyResume() external {
    vm.startPrank(owner);

    chainlinkOracle.emergencyPause();
    assertTrue(chainlinkOracle.paused(), "oracle should be paused");

    chainlinkOracle.emergencyResume();
    assertTrue(!chainlinkOracle.paused(), "oracle should not be paused");
  }

}
