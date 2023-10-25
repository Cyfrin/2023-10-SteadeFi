// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILBRouter {
  /**
   * @dev This enum represents the version of the pair requested
   * - V1: Joe V1 pair
   * - V2: LB pair V2. Also called legacyPair
   * - V2_1: LB pair V2.1 (current version)
   */
  enum Version {
    V1,
    V2,
    V2_1
  }

  /**
   * @dev The path parameters, such as:
   * - pairBinSteps: The list of bin steps of the pairs to go through
   * - versions: The list of versions of the pairs to go through
   * - tokenPath: The list of tokens in the path to go through
   */
  struct Path {
    uint256[] pairBinSteps;
    Version[] versions;
    IERC20[] tokenPath;
  }

 function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    Path memory path,
    address to,
    uint256 deadline
  ) external returns (uint256 amountOut);

  function swapExactTokensForNATIVE(
    uint256 amountIn,
    uint256 amountOutMinNATIVE,
    Path memory path,
    address payable to,
    uint256 deadline
  ) external returns (uint256 amountOut);

  function swapExactNATIVEForTokens(
    uint256 amountOutMin,
    Path memory path,
    address to,
    uint256 deadline
  ) external payable returns (uint256 amountOut);

  function swapTokensForExactTokens(
    uint256 amountOut,
    uint256 amountInMax,
    Path memory path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amountsIn);

  function swapTokensForExactNATIVE(
    uint256 amountOut,
    uint256 amountInMax,
    Path memory path,
    address payable to,
    uint256 deadline
  ) external returns (uint256[] memory amountsIn);

  function swapNATIVEForExactTokens(
    uint256 amountOut,
    Path memory path,
    address to,
    uint256 deadline
  ) external payable returns (uint256[] memory amountsIn);

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    Path memory path,
    address to,
    uint256 deadline
  ) external returns (uint256 amountOut);

  function swapExactTokensForNATIVESupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMinNATIVE,
    Path memory path,
    address payable to,
    uint256 deadline
  ) external returns (uint256 amountOut);

  function swapExactNATIVEForTokensSupportingFeeOnTransferTokens(
    uint256 amountOutMin,
    Path memory path,
    address to,
    uint256 deadline
  ) external payable returns (uint256 amountOut);
}
