// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { InvariantTest } from "forge-std/InvariantTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Contracts
import { Errors } from "../../../contracts/utils/Errors.sol";
import { LendingVault } from "../../../contracts/lending/LendingVault.sol";
import { GMXCallback } from "../../../contracts/strategy/gmx/GMXCallback.sol";
import { GMXVault } from "../../../contracts/strategy/gmx/GMXVault.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";

// Interfaces
import { IWNT } from "../../../contracts/interfaces/tokens/IWNT.sol";
import { ILendingVault } from "../../../contracts/interfaces/lending/ILendingVault.sol";
import { IGMXVault } from "../../../contracts/interfaces/strategy/gmx/IGMXVault.sol";
import { IGMXVaultEvents } from "../../../contracts/interfaces/strategy/gmx/IGMXVaultEvents.sol";
import { IGMXOracle } from "../../../contracts/interfaces/oracles/IGMXOracle.sol";
import { IExchangeRouter } from "../../../contracts/interfaces/protocols/gmx/IExchangeRouter.sol";
import { ISwap } from "../../../contracts/interfaces/swap/ISwap.sol";
import { IChainlinkOracle } from "../../../contracts/interfaces/oracles/IChainlinkOracle.sol";

// Mocks
import { MockWETH } from "../../../contracts/mocks/MockWETH.sol";
import { MockERC20 } from "../../../contracts/mocks/MockERC20.sol";
import { MockLendingVault } from "../../../contracts/mocks/MockLendingVault.sol";
import { MockStrategyVault } from "../../../contracts/mocks/MockStrategyVault.sol";
import { MockExchangeRouter } from "../../../contracts/mocks/gmx/MockExchangeRouter.sol";
import { MockGMXOracle } from "../../../contracts/mocks/gmx/MockGMXOracle.sol";
import { MockChainlinkOracle } from "../../../contracts/mocks/MockChainlinkOracle.sol";

// Mock Uniswap
import { UniswapV2Factory } from "../../../contracts/mocks/gmx/MockUniswapV2/UniswapV2Factory.sol";
import { UniswapV2Pair } from "../../../contracts/mocks/gmx/MockUniswapV2/UniswapV2Pair.sol";
import { UniswapV2Router02 } from "../../../contracts/mocks/gmx/MockUniswapV2/UniswapV2Router02.sol";
import { MockUniswapV2Oracle } from "../../../contracts/mocks/gmx/MockUniswapV2/MockUniswapV2Oracle.sol";
import { IUniswapV2Factory } from "../../../contracts/mocks/gmx/MockUniswapV2/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "../../../contracts/mocks/gmx/MockUniswapV2/interfaces/IUniswapV2Router02.sol";

contract GMXMockVaultSetup is IGMXVaultEvents, Test, InvariantTest {
  uint256 constant SAFE_MULTIPLIER = 1e18;

  address payable owner;
  address payable user1;
  address payable user2;
  address payable treasury;

  IERC20 USDC;
  IERC20 WETH;
  IERC20 ARB;

  MockLendingVault mockLendingVaultWETH;
  MockLendingVault mockLendingVaultUSDC;
  MockLendingVault mockLendingVaultARB;

  ILendingVault.InterestRate interestRateWETH;
  ILendingVault.InterestRate interestRateUSDC;
  ILendingVault.InterestRate maxInterestRate;

  GMXVault vault;
  GMXVault vaultARBUSDC;
  GMXVault vaultNeutral;
  GMXCallback callback;
  GMXCallback callbackNeutral;
  GMXTypes.Store store;
  GMXTypes.DepositCache depositCache;
  GMXTypes.WithdrawCache withdrawCache;
  GMXTypes.RebalanceCache rebalanceCache;
  GMXTypes.CompoundCache compoundCache;

  MockGMXOracle mockGMXOracle;
  MockChainlinkOracle mockChainlinkOracle;
  MockExchangeRouter mockExchangeRouter;

  MockUniswapV2Oracle mockUniswapV2Oracle;
  UniswapV2Factory mockUniswapV2Factory;
  UniswapV2Router02 mockUniswapV2Router02;
  UniswapV2Pair WETHUSDCpair;
  UniswapV2Pair ARBUSDCpair;

  function setUp() public {
    owner = payable(makeAddr("Owner"));
    user1 = payable(makeAddr("User1"));
    user2 = payable(makeAddr("User2"));
    treasury = payable(makeAddr("Treasury"));

    vm.startPrank(owner);

    WETH = new MockWETH();
    USDC = new MockERC20(6);
    ARB = new MockERC20(18);

    deal(address(WETH), 1000 ether);

    _setupLendingVaults();
    _setupMocks();

    // Setup GMX vault
    store = GMXTypes.Store(
      GMXTypes.Status.Open, // status
      0, // last fee collected
      payable(address(0)), // refundee
      3e18, // leverage
      GMXTypes.Delta.Long, // Delta 0: Neutral, 1: long
      5, // feePerSecond
      treasury, // treasury
      0.1e4, // debtRatioStepThreshold
      0.68e18, // debtRatioUpperLimit
      0.66e18, // debtRatioLowerLimit
      1.05e18, // deltaUpperLimit - unused for long
      0.95e18, // deltaLowerLimit - unused for long
      0.3e2, // minSlippage
      0.001e18, // minExecutionFee
      WETH, // tokenA
      USDC, // tokenB
      IERC20(address(WETHUSDCpair)), // lpToken
      IWNT(address(WETH)), // WNT
      mockLendingVaultWETH, // tokenALendingVault
      mockLendingVaultUSDC, // tokenBLendingVault
      IGMXVault(address(0)), // vault
      address(treasury), // trove
      address(0), // callback
      IChainlinkOracle(address(mockChainlinkOracle)), // chainlinkOracle
      IGMXOracle(address(mockGMXOracle)), // gmxOracle
      IExchangeRouter(address(mockExchangeRouter)), // exchangeRouter
      address(mockExchangeRouter), // router
      address(mockExchangeRouter), // depositVault
      address(mockExchangeRouter), // withdrawalVault
      address(mockExchangeRouter), // rolestore
      ISwap(address(mockExchangeRouter)), // swap router
      depositCache, // depositCache
      withdrawCache, // withdrawCache
      rebalanceCache, // rebalanceCache
      compoundCache // CompoundCache
    );

    vault = new GMXVault(
      "vault",
      "vault",
      store
    );

    store.tokenA = IERC20(address(ARB));
    store.tokenB = IERC20(address(USDC));

    vaultARBUSDC = new GMXVault(
      "vault",
      "vault",
      store
    );

    store.tokenA = IERC20(address(WETH));
    store.delta = GMXTypes.Delta.Neutral;
    store.deltaUpperLimit = 0.1e18;
    store.deltaLowerLimit = -0.1e18;

    vaultNeutral = new GMXVault(
      "vault",
      "vault",
      store
    );

    // Setup callback
    callback = new GMXCallback(address(vault));
    callbackNeutral = new GMXCallback(address(vaultNeutral));

    // Set ERC20 approvals
    vm.startPrank(owner);
    IERC20(USDC).approve(address(mockLendingVaultUSDC), type(uint256).max);
    IERC20(WETH).approve(address(mockLendingVaultWETH), type(uint256).max);
    IERC20(ARB).approve(address(mockLendingVaultARB), type(uint256).max);
    IERC20(USDC).approve(address(vault), type(uint256).max);
    IERC20(WETH).approve(address(vault), type(uint256).max);
    IERC20(ARB).approve(address(vault), type(uint256).max);
    IERC20(USDC).approve(address(vaultNeutral), type(uint256).max);
    IERC20(WETH).approve(address(vaultNeutral), type(uint256).max);
    IERC20(ARB).approve(address(vaultNeutral), type(uint256).max);

    vm.startPrank(address(vault));
    IERC20(USDC).approve(address(mockLendingVaultUSDC), type(uint256).max);
    IERC20(WETH).approve(address(mockLendingVaultWETH), type(uint256).max);
    IERC20(ARB).approve(address(mockLendingVaultARB), type(uint256).max);
    IERC20(USDC).approve(address(mockExchangeRouter), type(uint256).max);
    IERC20(WETH).approve(address(mockExchangeRouter), type(uint256).max);
    IERC20(ARB).approve(address(mockExchangeRouter), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(address(vaultNeutral));
    IERC20(USDC).approve(address(mockLendingVaultUSDC), type(uint256).max);
    IERC20(WETH).approve(address(mockLendingVaultWETH), type(uint256).max);
    IERC20(ARB).approve(address(mockLendingVaultARB), type(uint256).max);
    IERC20(USDC).approve(address(mockExchangeRouter), type(uint256).max);
    IERC20(WETH).approve(address(mockExchangeRouter), type(uint256).max);
    IERC20(ARB).approve(address(mockExchangeRouter), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(address(mockExchangeRouter));
    IERC20(USDC).approve(address(mockUniswapV2Router02), type(uint256).max);
    IERC20(WETH).approve(address(mockUniswapV2Router02), type(uint256).max);
    IERC20(ARB).approve(address(mockUniswapV2Router02), type(uint256).max);

    vm.startPrank(user1);
    IERC20(USDC).approve(address(vault), type(uint256).max);
    IERC20(WETH).approve(address(vault), type(uint256).max);
    IERC20(ARB).approve(address(vault), type(uint256).max);
     IERC20(USDC).approve(address(vaultNeutral), type(uint256).max);
    IERC20(WETH).approve(address(vaultNeutral), type(uint256).max);
    IERC20(ARB).approve(address(vaultNeutral), type(uint256).max);

    // Deal token balances
    deal(owner, 10 ether);
    deal(address(WETH), owner, 10000 ether);
    deal(address(USDC), owner, 10000000e6);
    deal(address(ARB), owner, 10000e18);

    deal(user1, 10 ether);
    deal(address(WETH), user1, 10 ether);
    deal(address(USDC), user1, 10000e6);
    deal(address(ARB), user1, 1000e18);

    // Seed lending vaults
    vm.startPrank(owner);
    mockLendingVaultWETH.deposit(1000 ether, 0);
    mockLendingVaultUSDC.deposit(100_000e6, 0);
    mockLendingVaultARB.deposit(1000e18, 0);
    mockLendingVaultWETH.approveBorrower(address(owner));
    mockLendingVaultUSDC.approveBorrower(address(owner));
    mockLendingVaultARB.approveBorrower(address(owner));
    mockLendingVaultWETH.borrow(1e9);
    mockLendingVaultUSDC.borrow(1e6);
    mockLendingVaultARB.borrow(1e18);

    // Seed mock LP
    WETH.transfer(address(WETHUSDCpair), 100 ether);
    USDC.transfer(address(WETHUSDCpair), 160_000e6);
    WETHUSDCpair.mint(address(owner));

    ARB.transfer(address(ARBUSDCpair), 1000e18);
    USDC.transfer(address(ARBUSDCpair), 1000e6);
    ARBUSDCpair.mint(address(owner));

    // Approve vault as borrower
    mockLendingVaultWETH.approveBorrower(address(vault));
    mockLendingVaultUSDC.approveBorrower(address(vault));
    mockLendingVaultARB.approveBorrower(address(vault));
     mockLendingVaultWETH.approveBorrower(address(vaultNeutral));
    mockLendingVaultUSDC.approveBorrower(address(vaultNeutral));
    mockLendingVaultARB.approveBorrower(address(vaultNeutral));

    // Approve keepers
    vault.updateKeeper(address(owner), true);
    vault.updateKeeper(address(user1), true);
    vault.updateKeeper(address(callback), true);
    vaultNeutral.updateKeeper(address(owner), true);
    vaultNeutral.updateKeeper(address(user1), true);
    vaultNeutral.updateKeeper(address(callbackNeutral), true);
  }

  function _setupLendingVaults() internal {
    interestRateWETH = ILendingVault.InterestRate(
      0, // Base rate: rate which is the y-intercept when utilization rate is 0 in 1e18
      0.125 ether, // Multiplier: multiplier of utilization rate that gives the slope of the interest rate in 1e18
      2.5 ether, // Jump Multiplier: multiplier after hitting a specified utilization point (kink2) in 1e18
      0.8 ether, // Kink1: utilization point at which the interest rate is fixed in 1e18
      0.9 ether // Kink2: utilization point at which the jump multiplier is applied in 1e18
    );

    interestRateUSDC = ILendingVault.InterestRate(
      0,
      0.13 ether,
      8 ether,
      0.8 ether,
      0.9 ether
    );

    maxInterestRate = ILendingVault.InterestRate(
      0,
      0.2 ether,
      10 ether,
      0.8 ether,
      0.9 ether
    );

    mockLendingVaultWETH = new MockLendingVault(
      "WETH Lending Vault",
      "lvWETH",
      IERC20(WETH),
      true,
      0.2 ether,
      type(uint256).max,
      treasury,
      interestRateWETH,
      maxInterestRate
    );

    mockLendingVaultUSDC = new MockLendingVault(
      "USDC Lending Vault",
      "lvUSDC",
      IERC20(USDC),
      false,
      0.2 ether,
      type(uint256).max,
      treasury,
      interestRateUSDC,
      maxInterestRate
    );

    mockLendingVaultWETH = new MockLendingVault(
      "Mock WETH Lending Vault",
      "mlvWETH",
      IERC20(WETH),
      true,
      0.2 ether,
      type(uint256).max,
      treasury,
      interestRateWETH,
      maxInterestRate
    );

    mockLendingVaultARB = new MockLendingVault(
      "Mock ARB Lending Vault",
      "mlvARB",
      IERC20(ARB),
      true,
      0.2 ether,
      type(uint256).max,
      treasury,
      interestRateWETH,
      maxInterestRate
    );

    mockLendingVaultWETH.updateKeeper(address(owner), true);
    mockLendingVaultUSDC.updateKeeper(address(owner), true);
    mockLendingVaultARB.updateKeeper(address(owner), true);
  }

  function _setupMocks() internal {
    // Setup Chainlink mocks
    mockChainlinkOracle = new MockChainlinkOracle();
    mockChainlinkOracle.set(address(WETH), 1600e18, 18);
    mockChainlinkOracle.set(address(USDC), 1e6, 6);
    mockChainlinkOracle.set(address(ARB), 1e18, 18);

    // Setup Uniswap mock WETH/USDC pool
    mockUniswapV2Factory = new UniswapV2Factory(address(owner));
    mockUniswapV2Router02 = new UniswapV2Router02(address(mockUniswapV2Factory), address(WETH));
    address _WETHUSDCpair = mockUniswapV2Factory.createPair(address(WETH), address(USDC));
    WETHUSDCpair = UniswapV2Pair(_WETHUSDCpair);
    mockUniswapV2Oracle = new MockUniswapV2Oracle(
      IUniswapV2Factory(address(mockUniswapV2Factory)),
      IUniswapV2Router02(address(mockUniswapV2Router02)),
      MockChainlinkOracle(address(mockChainlinkOracle))
    );

    // Setup Uniswap mock ARB/USDC pool
    address _ARBUSDCpair = mockUniswapV2Factory.createPair(address(ARB), address(USDC));
    ARBUSDCpair = UniswapV2Pair(_ARBUSDCpair);

    // console2.log("pair address", _WETHUSDCpair);
    // // console2.log("pair codehash");
    // console2.logBytes32(keccak256(type(UniswapV2Pair).creationCode));

    // Setup GMX mocks
    mockExchangeRouter = new MockExchangeRouter(
      address(WETH),
      address(mockUniswapV2Router02),
      address(mockUniswapV2Factory),
      address(mockUniswapV2Oracle)
    );
    mockGMXOracle = new MockGMXOracle(IChainlinkOracle(address(mockChainlinkOracle)), mockExchangeRouter);
  }
}
