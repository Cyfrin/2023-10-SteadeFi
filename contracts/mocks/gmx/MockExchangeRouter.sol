// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IExchangeRouter } from  "../../interfaces/protocols/gmx/IExchangeRouter.sol";
import { IDeposit } from "../../interfaces/protocols/gmx/IDeposit.sol";
import { IWithdrawal } from "../../interfaces/protocols/gmx/IWithdrawal.sol";
import { IEvent } from "../../interfaces/protocols/gmx/IEvent.sol";
import { ISwap } from "../../interfaces/swap/ISwap.sol";
import { IUniswapV2Router02 } from "./MockUniswapV2/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "./MockUniswapV2/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "./MockUniswapV2/interfaces/IUniswapV2Factory.sol";
import { MockUniswapV2Oracle } from "./MockUniswapV2/MockUniswapV2Oracle.sol";
import { IWETH } from "./MockUniswapV2/interfaces/IWETH.sol";

import { console } from "forge-std/console.sol";

interface ICallback {
  function afterDepositExecution(
    bytes32 depositKey,
    IDeposit.Props memory depositProps,
    IEvent.Props memory eventData
  ) external;

  function afterDepositCancellation(
    bytes32 depositKey,
    IDeposit.Props memory depositProps,
    IEvent.Props memory eventData
  ) external;

  function afterWithdrawalExecution(
    bytes32 withdrawKey,
    IWithdrawal.Props memory withdrawalProps,
    IEvent.Props memory eventData
  ) external;

  function afterWithdrawalCancellation(
    bytes32 withdrawKey,
    IWithdrawal.Props memory withdrawalProps,
    IEvent.Props memory eventData
  ) external;
}

contract MockExchangeRouter {
  bytes32 depositKey;
  bytes32 withdrawKey;

  IWETH WETH;
  IUniswapV2Router02 public uniswapRouter;
  IUniswapV2Factory public uniswapFactory;
  MockUniswapV2Oracle public uniswapV2Oracle;

  IDeposit.Props public depositProps;
  IWithdrawal.Props public withdrawalProps;
  IEvent.Props public eventProps;

  constructor(address _WETH, address _uniswapRouter, address _uniswapFactory, address _uniswapV2Oracle) {
    WETH = IWETH(_WETH);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    uniswapFactory = IUniswapV2Factory(_uniswapFactory);
    uniswapV2Oracle = MockUniswapV2Oracle(_uniswapV2Oracle);
  }

  function createDeposit(IExchangeRouter.CreateDepositParams memory /*_cdp*/) external returns (bytes32 key) {
    key = bytes32(keccak256(abi.encodePacked(msg.sender)));
    depositKey = key;
  }

  function executeDeposit(
    address tokenA,
    address tokenB,
    address vault,
    address callback
  ) external {
    _swapForDeposit(tokenA, tokenB);

    uniswapRouter.addLiquidity(
      tokenA,
      tokenB,
      IERC20(tokenA).balanceOf(address(this)),
      IERC20(tokenB).balanceOf(address(this)),
      vault,
      block.timestamp + 1
    );

    ICallback(callback).afterDepositExecution(depositKey, depositProps, eventProps);
  }

  function executeMockDeposit(
    address tokenA,
    address tokenB,
    uint256 tokenAAmt,
    uint256 tokenBAmt,
    uint256 mintAmt,
    uint256 burnAmt,
    address vault,
    address callback
  ) external {
    address pair = uniswapFactory.getPair(tokenA, tokenB);
    IUniswapV2Pair(pair).superMint(address(vault), mintAmt);
    IUniswapV2Pair(pair).superBurn(address(vault), burnAmt);
    IUniswapV2Pair(pair).superTransfer(tokenA, vault, tokenAAmt);
    IUniswapV2Pair(pair).superTransfer(tokenB, vault, tokenBAmt);

    ICallback(callback).afterDepositExecution(depositKey, depositProps, eventProps);
  }

  function cancelDeposit(
    address tokenA,
    address tokenB,
    address vault,
    address callback) external {
    IERC20(tokenA).transfer(vault, IERC20(tokenA).balanceOf(address(this)));
    IERC20(tokenB).transfer(vault, IERC20(tokenB).balanceOf(address(this)));

    ICallback(callback).afterDepositCancellation(depositKey, depositProps, eventProps);
  }

  function createWithdrawal(
    IExchangeRouter.CreateWithdrawalParams memory
    /*_cwp*/
  ) external returns (bytes32 key) {
    key = bytes32(keccak256(abi.encodePacked(msg.sender)));
    withdrawKey = key;
  }

  function executeWithdrawal(
    address tokenA,
    address tokenB,
    address vault,
    address callback
  ) external {
    address pair = uniswapFactory.getPair(tokenA, tokenB);

    uniswapRouter.removeLiquidity(
      tokenA,
      tokenB,
      IERC20(pair).balanceOf(address(this)),
      0,
      0,
      vault,
      block.timestamp + 1
    );

    ICallback(callback).afterWithdrawalExecution(withdrawKey, withdrawalProps, eventProps);
  }

  function executeMockWithdrawal(
    address tokenA,
    address tokenB,
    uint256 tokenAAmt,
    uint256 tokenBAmt,
    uint256 mintAmt,
    uint256 burnAmt,
    address vault,
    address callback
  ) external {
    address pair = uniswapFactory.getPair(tokenA, tokenB);
    IUniswapV2Pair(pair).superMint(address(vault), mintAmt);
    IUniswapV2Pair(pair).superBurn(address(vault), burnAmt);
    IUniswapV2Pair(pair).superTransfer(tokenA, vault, tokenAAmt);
    IUniswapV2Pair(pair).superTransfer(tokenB, vault, tokenBAmt);

    ICallback(callback).afterWithdrawalExecution(withdrawKey, withdrawalProps, eventProps);
  }

  function cancelWithdrawal(
    address tokenA,
    address tokenB,
    address vault,
    address callback
  ) external {
    address pair = uniswapFactory.getPair(tokenA, tokenB);
    IERC20(pair).transfer(vault, IERC20(pair).balanceOf(address(this)));

    ICallback(callback).afterWithdrawalCancellation(withdrawKey, withdrawalProps, eventProps);
  }

  function swapExactTokensForTokens(ISwap.SwapParams memory sp) external returns (uint256 amtOut) {
    IERC20(sp.tokenIn).transferFrom(msg.sender, address(this), sp.amountIn);
    address[] memory path = new address[](2);
    path[0] = sp.tokenIn;
    path[1] = sp.tokenOut;
    try
    uniswapRouter.swapExactTokensForTokens(
      sp.amountIn,
      sp.amountOut,
      path,
      address(this),
      block.timestamp + 1
    ) {
      amtOut = IERC20(sp.tokenOut).balanceOf(address(this));

      IERC20(sp.tokenIn).transfer(msg.sender, IERC20(sp.tokenIn).balanceOf(address(this)));
      IERC20(sp.tokenOut).transfer(msg.sender, IERC20(sp.tokenOut).balanceOf(address(this)));
    } catch (bytes memory/*reason*/) {
    }
  }

  function swapTokensForExactTokens(ISwap.SwapParams memory sp) external returns(uint256 amtIn) {
    IERC20(sp.tokenIn).transferFrom(msg.sender, address(this), sp.amountIn);
    address[] memory path = new address[](2);
    path[0] = sp.tokenIn;
    path[1] = sp.tokenOut;
    try
    uniswapRouter.swapTokensForExactTokens(
      sp.amountOut,
      sp.amountIn,
      path,
      address(this),
      block.timestamp + 1
    ) {
      amtIn = sp.amountIn;

      IERC20(sp.tokenIn).transfer(msg.sender, IERC20(sp.tokenIn).balanceOf(address(this)));
      IERC20(sp.tokenOut).transfer(msg.sender, IERC20(sp.tokenOut).balanceOf(address(this)));
    } catch (bytes memory/*reason*/) {
    }
  }

  // getMarketTokenInfo() should return price in 1e30
  function getMarketTokenInfo(
    address /* _marketToken */,
    address /* _indexToken */,
    address _longToken,
    address _shortToken,
    bool /* isDeposit */,
    bool /* maximise */
  ) external view returns (uint256) {
    address pair = uniswapFactory.getPair(_longToken, _shortToken);
    uint256 price1e8 = uniswapV2Oracle.getLpTokenValue(1e18, _longToken, _shortToken, IUniswapV2Pair(pair));

    return price1e8 * 1e22;
  }

  function sendTokens(
    address token,
    address to,
    uint256 amt
  ) external {
    IERC20(token).transferFrom(msg.sender, to, amt);
  }

  function sendWnt(address /*to*/, uint256 /*amt*/) external payable {
    WETH.deposit{value: msg.value}();
  }

  function _swapForDeposit(address tokenA, address tokenB) internal {
    address pair = uniswapFactory.getPair(tokenA, tokenB);
    (uint256 reserveA, uint256 reserveB) = uniswapV2Oracle.getLpTokenReserves(
      IERC20(pair).totalSupply(),
      address(tokenA),
      address(tokenB),
      IUniswapV2Pair(pair)
    );

    // Calculate optimal deposit for token0
    (uint256 optimalSwapAmount, bool isReversed) = optimalDeposit(
      IERC20(tokenA).balanceOf(address(this)),
      IERC20(tokenB).balanceOf(address(this)),
      reserveA,
      reserveB,
      3 // fee of 0.3%
    );

    address[] memory swapPathForOptimalDeposit = new address[](2);

    if (isReversed) {
      swapPathForOptimalDeposit[0] = address(tokenB);
      swapPathForOptimalDeposit[1] = address(tokenA);
    } else {
      swapPathForOptimalDeposit[0] = address(tokenA);
      swapPathForOptimalDeposit[1] = address(tokenB);
    }

    // Swap tokens to achieve optimal deposit amount
    if (optimalSwapAmount > 0) {
      uniswapRouter.swapExactTokensForTokens(
        optimalSwapAmount,
        0,
        swapPathForOptimalDeposit,
        address(this),
        block.timestamp
      );
    }
  }

  function optimalDeposit(
    uint256 _amountA,
    uint256 _amountB,
    uint256 _reserveA,
    uint256 _reserveB,
    uint256 _fee
  ) public pure returns (uint256, bool) {
    uint256 swapAmt;
    bool isReversed;

    if (_amountA * _reserveB >= _amountB * _reserveA) {
      swapAmt = _optimalDeposit(_amountA, _amountB, _reserveA, _reserveB, _fee);
      isReversed = false;
    } else {
      swapAmt = _optimalDeposit(_amountB, _amountA, _reserveB, _reserveA, _fee);
      isReversed = true;
    }

    return (swapAmt, isReversed);
  }

  function _optimalDeposit(
    uint256 _amountA,
    uint256 _amountB,
    uint256 _reserveA,
    uint256 _reserveB,
    uint256 _fee
  ) internal pure returns (uint256) {
      require(_amountA * _reserveB >= _amountB * _reserveA, "Reversed");

      uint256 a = 1000 - _fee;
      uint256 b = (2000 - _fee) * _reserveA;
      uint256 _c = (_amountA * _reserveB) - (_amountB * _reserveA);
      uint256 c = _c * 1000 / (_amountB + _reserveB) * _reserveA;
      uint256 d = a * c * 4;
      uint256 e = Math.sqrt(b * b + d);
      uint256 numerator = e - b;
      uint256 denominator = a * 2;

      return numerator / denominator;
  }

  function hasRole(address /* acc */, bytes32 /* role */) external pure returns (bool) {
    return true;
  }

  receive() external payable {}
}
