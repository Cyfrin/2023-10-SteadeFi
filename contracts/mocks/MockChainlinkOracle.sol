// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MockChainlinkOracle is Ownable2Step, Pausable {
  using SafeCast for int256;

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ======================= MAPPINGS ======================== */

  // Mapping of token to mock price
  mapping(address => uint256) public price;
  mapping(address => uint8) public decimals;

  /* ====================== CONSTRUCTOR ====================== */

  constructor() Ownable(msg.sender) {}

  /* ========== EXTERNAL FUNCTIONS ========== */
  function set(address _token, uint256 _price, uint8 _decimals) external {
    price[_token] = _price;
    decimals[_token] = _decimals;
  }

  /* ===================== VIEW FUNCTIONS ==================== */

  /**
    * Get token price from Chainlink feed
    * @param _token Token address
    * @return price Asset price in int256
    * @return decimals Price decimals in uint8
    */
  function consult(address _token) public view whenNotPaused returns (int256, uint8) {
    int256 _answer = int256(price[_token]);
    uint8 _decimals = decimals[_token];
    return (_answer, _decimals);
  }

  /**
    * Get token price from Chainlink feed returned in 1e18
    * @param _token Token address
    * @return price Asset price; expressed in 1e18
    */
  function consultIn18Decimals(address _token) external view whenNotPaused returns (uint256) {
    (int256 _answer, uint8 _decimals) = consult(_token);

    return _answer.toUint256() * 1e18 / (10 ** _decimals);
  }
}
