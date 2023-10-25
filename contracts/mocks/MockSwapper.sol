// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISwap {
  struct SwapParams {
    // Address of token in
    address tokenIn;
    // Address of token out
    address tokenOut;
    // Amount of token in; in token decimals
    uint256 amountIn;
    // Fee in LP pool, 500 = 0.05%, 3000 = 0.3%
    uint24 fee;
    // Slippage tolerance swap; e.g. 3 = 0.03%
    uint256 slippage;
    // Swap deadline timestamp
    uint256 deadline;
  }
}

contract MockSwapper {
  using SafeERC20 for IERC20;

  address WETH;
  address USDC;
  uint256 ethPrice;

  function swap(
    ISwap.SwapParams memory sp
  ) external returns (uint256) {
    if (sp.tokenIn == WETH) {
      IERC20(WETH).safeTransferFrom(msg.sender, address(this), sp.amountIn);

      uint256 amountOut = sp.amountIn * ethPrice / 1e12;

      IERC20(USDC).safeTransfer(msg.sender, amountOut);

      return amountOut;
    } else if (sp.tokenIn == USDC) {
      IERC20(USDC).safeTransferFrom(msg.sender, address(this), sp.amountIn);

      uint256 amountOut = sp.amountIn * 1e12 * 1e18 / ethPrice;

      IERC20(WETH).safeTransfer(msg.sender, amountOut);

      return amountOut;
    } else {
      revert("MockSwapper: unsupported token");
    }
  }

  function setEthPrice(uint256 _ethPrice) external {
    ethPrice = _ethPrice;
  }
}
