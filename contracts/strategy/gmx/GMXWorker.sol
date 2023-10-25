// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IExchangeRouter } from  "../../interfaces/protocols/gmx/IExchangeRouter.sol";
import { ISwap } from  "../../interfaces/swap/ISwap.sol";
import { GMXTypes } from "./GMXTypes.sol";

library GMXWorker {

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @dev Add strategy's tokens for liquidity and receive LP tokens
    * @param self Vault store data
    * @param alp GMXTypes.AddLiquidityParams
    * @return depositKey Hashed key of created deposit in bytes32
  */
  function addLiquidity(
    GMXTypes.Store storage self,
    GMXTypes.AddLiquidityParams memory alp
  ) external returns (bytes32) {
    // Send native token for execution fee
    self.exchangeRouter.sendWnt{ value: alp.executionFee }(
      self.depositVault,
      alp.executionFee
    );

    // Send tokens
    self.exchangeRouter.sendTokens(
      address(self.tokenA),
      self.depositVault,
      alp.tokenAAmt
    );

    self.exchangeRouter.sendTokens(
      address(self.tokenB),
      self.depositVault,
      alp.tokenBAmt
    );

    // Create deposit
    IExchangeRouter.CreateDepositParams memory _cdp =
      IExchangeRouter.CreateDepositParams({
        receiver: address(this),
        callbackContract: self.callback,
        uiFeeReceiver: self.refundee,
        market: address(self.lpToken),
        initialLongToken: address(self.tokenA),
        initialShortToken: address(self.tokenB),
        longTokenSwapPath: new address[](0),
        shortTokenSwapPath: new address[](0),
        minMarketTokens: alp.minMarketTokenAmt,
        shouldUnwrapNativeToken: false,
        executionFee: alp.executionFee,
        callbackGasLimit: 2000000
      });

    return self.exchangeRouter.createDeposit(_cdp);
  }

  /**
    * @dev Remove liquidity of strategy's LP token and receive underlying tokens
    * @param self Vault store data
    * @param rlp GMXTypes.RemoveLiquidityParams
    * @return withdrawKey Hashed key of created withdraw in bytes32
  */
  function removeLiquidity(
    GMXTypes.Store storage self,
    GMXTypes.RemoveLiquidityParams memory rlp
  ) external returns (bytes32) {
    // Send native token for execution fee
    self.exchangeRouter.sendWnt{value: rlp.executionFee }(
      self.withdrawalVault,
      rlp.executionFee
    );

    // Send GM LP tokens
    self.exchangeRouter.sendTokens(
      address(self.lpToken),
      self.withdrawalVault,
      rlp.lpAmt
    );

    // Create withdrawal
    IExchangeRouter.CreateWithdrawalParams memory _cwp =
      IExchangeRouter.CreateWithdrawalParams({
        receiver: address(this),
        callbackContract: self.callback,
        uiFeeReceiver: self.refundee,
        market: address(self.lpToken),
        longTokenSwapPath: rlp.tokenASwapPath,
        shortTokenSwapPath: rlp.tokenBSwapPath,
        minLongTokenAmount: rlp.minTokenAAmt,
        minShortTokenAmount: rlp.minTokenBAmt,
        shouldUnwrapNativeToken: false,
        executionFee: rlp.executionFee,
        callbackGasLimit: 2000000
      });

    return self.exchangeRouter.createWithdrawal(_cwp);
  }

  /**
    * @dev Swap exact amount of tokenIn for as many amount of tokenOut
    * @param self Vault store data
    * @param sp ISwap.SwapParams
    * @return amountOut Amount of tokens out in token decimals
  */
  function swapExactTokensForTokens(
    GMXTypes.Store storage self,
    ISwap.SwapParams memory sp
  ) external returns (uint256) {
    IERC20(sp.tokenIn).approve(address(self.swapRouter), sp.amountIn);

    return self.swapRouter.swapExactTokensForTokens(sp);
  }

  /**
    * @dev Swap as little tokenIn for exact amount of tokenOut
    * @param self Vault store data
    * @param sp ISwap.SwapParams
    * @return amountIn Amount of tokens in in token decimals
  */
  function swapTokensForExactTokens(
    GMXTypes.Store storage self,
    ISwap.SwapParams memory sp
  ) external returns (uint256) {
    IERC20(sp.tokenIn).approve(address(self.swapRouter), sp.amountIn);

    return self.swapRouter.swapTokensForExactTokens(sp);
  }
}
