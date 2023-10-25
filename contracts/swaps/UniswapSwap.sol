// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IChainlinkOracle } from  "../interfaces/oracles/IChainlinkOracle.sol";
import { ISwapRouter } from "../interfaces/protocols/uniswap/ISwapRouter.sol";
import { ISwap } from "../interfaces/swap/ISwap.sol";
import { Errors } from "../utils/Errors.sol";

contract UniswapSwap is Ownable2Step, ISwap {
  using SafeERC20 for IERC20;

  /* ==================== STATE VARIABLES ==================== */

  // Address of Uniswap router
  ISwapRouter public router;
  // Address of Chainlink oracle
  IChainlinkOracle public oracle;

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ======================= MAPPINGS ======================== */

  // Mapping of fee tier for tokenIn => tokenOut which determines swap pool
  mapping(address => mapping(address => uint24)) public fees;

  /* ======================== EVENTS ========================= */

  event UpdateFee(address tokenIn, address tokenOut, uint24 fee);

  /* ====================== CONSTRUCTOR ====================== */

  /**
    * @param _router Address of router of swap
    * @param _oracle Address of Chainlink oracle
  */
  constructor(ISwapRouter _router, IChainlinkOracle _oracle) Ownable(msg.sender) {
    if (
      address(_router) == address(0) ||
      address(_oracle) == address(0)
    ) revert Errors.ZeroAddressNotAllowed();

    router = ISwapRouter(_router);
    oracle = IChainlinkOracle(_oracle);
  }

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice Swap exact amount of tokenIn for as many amount of tokenOut
    * @param sp ISwap.SwapParams
    * @return amountOut Amount of tokens out; in token decimals
  */
  function swapExactTokensForTokens(ISwap.SwapParams memory sp) external returns (uint256) {
    IERC20(sp.tokenIn).safeTransferFrom(msg.sender, address(this), sp.amountIn);

    IERC20(sp.tokenIn).approve(address(router), sp.amountIn);

    uint256 _valueIn = sp.amountIn * oracle.consultIn18Decimals(sp.tokenIn) / SAFE_MULTIPLIER;

    uint256 _amountOutMinimum = _valueIn
      * SAFE_MULTIPLIER
      / oracle.consultIn18Decimals(sp.tokenOut)
      / (10 ** (18 - IERC20Metadata(sp.tokenOut).decimals()))
      * (10000 - sp.slippage) / 10000;

    ISwapRouter.ExactInputSingleParams memory _eisp =
      ISwapRouter.ExactInputSingleParams({
        tokenIn: sp.tokenIn,
        tokenOut: sp.tokenOut,
        fee: fees[sp.tokenIn][sp.tokenOut],
        recipient: address(this),
        deadline: sp.deadline,
        amountIn: sp.amountIn,
        amountOutMinimum: _amountOutMinimum,
        sqrtPriceLimitX96: 0
      });

    router.exactInputSingle(_eisp);

    uint256 _amountOut = IERC20(sp.tokenOut).balanceOf(address(this));

    IERC20(sp.tokenOut).safeTransfer(msg.sender, _amountOut);

    return _amountOut;
  }

  /**
    * @notice Swap as little tokenIn for exact amount of tokenOut
    * @param sp ISwap.SwapParams
    * @return amountIn Amount of tokens in swapepd; in token decimals
  */
  function swapTokensForExactTokens(ISwap.SwapParams memory sp) external returns (uint256) {
    IERC20(sp.tokenIn).safeTransferFrom(
      msg.sender,
      address(this),
      sp.amountIn
    );

    IERC20(sp.tokenIn).approve(address(router), sp.amountIn);

    ISwapRouter.ExactOutputSingleParams memory _eosp =
      ISwapRouter.ExactOutputSingleParams({
        tokenIn: sp.tokenIn,
        tokenOut: sp.tokenOut,
        fee: fees[sp.tokenIn][sp.tokenOut],
        recipient: address(this),
        deadline: sp.deadline,
        amountOut: sp.amountOut,
        amountInMaximum: sp.amountIn,
        sqrtPriceLimitX96: 0
      });

    uint256 _amountIn = router.exactOutputSingle(_eosp);

    // Return sender back any unused tokenIn
    IERC20(sp.tokenIn).safeTransfer(
      msg.sender,
      IERC20(sp.tokenIn).balanceOf(address(this))
    );

    IERC20(sp.tokenOut).safeTransfer(
      msg.sender,
      IERC20(sp.tokenOut).balanceOf(address(this))
    );

    return _amountIn;
  }

  /* ================= RESTRICTED FUNCTIONS ================== */

  /**
    * @notice Update fee tier for tokenIn => tokenOut which determines the swap pool to
    * swap tokenIn for tokenOut at
    * @dev To add tokenIn/Out for both ways of the token swap to ensure the same swap pool is used
    * for the swap in both directions
    * @param tokenIn Address of token to swap from
    * @param tokenOut Address of token to swap to
    * @param fee Fee tier of the liquidity pool in uint24
  */
  function updateFee(address tokenIn, address tokenOut, uint24 fee) external onlyOwner {
    if (tokenIn == address(0) || tokenOut == address(0)) revert Errors.ZeroAddressNotAllowed();

    fees[tokenIn][tokenOut] = fee;

    emit UpdateFee(tokenIn, tokenOut, fee);
  }
}
