// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IChainlinkOracle } from  "../interfaces/oracles/IChainlinkOracle.sol";
import { ILBRouter } from "../interfaces/protocols/trader-joe/ILBRouter.sol";
import { ISwap } from "../interfaces/swap/ISwap.sol";
import { Errors } from "../utils/Errors.sol";

contract TraderJoeSwap is Ownable2Step, ISwap {
  using SafeERC20 for IERC20;

  /* ==================== STATE VARIABLES ==================== */

  // Address of Trader Joe router
  ILBRouter public router;
  // Address of Chainlink oracle
  IChainlinkOracle public oracle;

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ======================= MAPPINGS ======================== */

  // Mapping of pair bin steps for tokenIn => tokenOut which determines swap pool
  mapping(address => mapping(address => uint256)) public pairBinSteps;

  /* ======================== EVENTS ========================= */

  event UpdatePairBinStep(address tokenIn, address tokenOut, uint256 pairBinStep);

  /* ====================== CONSTRUCTOR ====================== */

  /**
    * @param _router Address of router of swap
    * @param _oracle Address of Chainlink oracle
  */
  constructor(ILBRouter _router, IChainlinkOracle _oracle) Ownable(msg.sender) {
    if (
      address(_router) == address(0) ||
      address(_oracle) == address(0)
    ) revert Errors.ZeroAddressNotAllowed();

    router = ILBRouter(_router);
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

    uint256[] memory _pairBinSteps = new uint256[](1);
    _pairBinSteps[0] = pairBinSteps[sp.tokenIn][sp.tokenOut];

    IERC20[] memory _tokenPath = new IERC20[](2);
    _tokenPath[0] = IERC20(sp.tokenIn);
    _tokenPath[1] = IERC20(sp.tokenOut);

    ILBRouter.Version[] memory _versions = new ILBRouter.Version[](1);
    _versions[0] = ILBRouter.Version.V2_1;

    ILBRouter.Path memory _path; // instanciate and populate the path to perform the swap.
    _path.pairBinSteps = _pairBinSteps;
    _path.versions = _versions;
    _path.tokenPath = _tokenPath;

    uint256 _valueIn = sp.amountIn * oracle.consultIn18Decimals(sp.tokenIn) / SAFE_MULTIPLIER;

    uint256 _amountOutMinimum = _valueIn
      * SAFE_MULTIPLIER
      / oracle.consultIn18Decimals(sp.tokenOut)
      / (10 ** (18 - IERC20Metadata(sp.tokenOut).decimals()))
      * (10000 - sp.slippage) / 10000;

    uint256 _amountOut = router.swapExactTokensForTokens(
      sp.amountIn,
      _amountOutMinimum,
      _path,
      address(this),
      sp.deadline
    );

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

    uint256[] memory _pairBinSteps = new uint256[](1);
    _pairBinSteps[0] = pairBinSteps[sp.tokenIn][sp.tokenOut];

    IERC20[] memory _tokenPath = new IERC20[](2);
    _tokenPath[0] = IERC20(sp.tokenIn);
    _tokenPath[1] = IERC20(sp.tokenOut);

    ILBRouter.Version[] memory _versions = new ILBRouter.Version[](1);
    _versions[0] = ILBRouter.Version.V2_1;

    ILBRouter.Path memory _path; // instanciate and populate the path to perform the swap.
    _path.pairBinSteps = _pairBinSteps;
    _path.versions = _versions;
    _path.tokenPath = _tokenPath;

    uint256[] memory _amountIn = router.swapTokensForExactTokens(
      sp.amountOut,
      sp.amountIn,
      _path,
      address(this),
      sp.deadline
    );

    // Return sender back any unused tokenIn
    IERC20(sp.tokenIn).safeTransfer(
      msg.sender,
      IERC20(sp.tokenIn).balanceOf(address(this))
    );

    IERC20(sp.tokenOut).safeTransfer(
      msg.sender,
      IERC20(sp.tokenOut).balanceOf(address(this))
    );

    // First value in array is the amountIn used for tokenIn
    return _amountIn[0];
  }

  /* ================= RESTRICTED FUNCTIONS ================== */

  /**
    * @notice Update pair bin step for tokenIn => tokenOut which determines the swap pool to
    * swap tokenIn for tokenOut at
    * @dev To add tokenIn/Out for both ways of the token swap to ensure the same swap pool is used
    * for the swap in both directions
    * @param tokenIn Address of token to swap from
    * @param tokenOut Address of token to swap to
    * @param pairBinStep Pair bin step for the liquidity pool in uint256
  */
  function updatePairBinStep(address tokenIn, address tokenOut, uint256 pairBinStep) external onlyOwner {
    if (tokenIn == address(0) || tokenOut == address(0)) revert Errors.ZeroAddressNotAllowed();

    pairBinSteps[tokenIn][tokenOut] = pairBinStep;

    emit UpdatePairBinStep(tokenIn, tokenOut, pairBinStep);
  }
}
