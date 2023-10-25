// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract TestUtils is Test {
  function expectRevert(string memory errorMsg) public {
    bytes4 selector = bytes4(keccak256(abi.encodePacked(errorMsg)));
    vm.expectRevert(selector);
  }

  function getBytes(string memory errorMsg) public pure returns (bytes memory) {
    return abi.encodePacked(bytes4(keccak256(abi.encodePacked(errorMsg))));
  }

  function roughlyEqual(uint256 a, uint256 b, uint256 diff) public pure returns (bool) {
    return a >= b - diff && a <= b + diff;
  }

  function abs(int256 a) public pure returns (uint256) {
    return a >= 0 ? uint256(a) : uint256(-a);
  }
}
