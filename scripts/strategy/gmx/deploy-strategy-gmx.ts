import hre from 'hardhat';
import { ethers } from "hardhat";
import * as request from 'request';
import * as dotenv from "dotenv";
import { CONSTANTS } from '../../../constants';

dotenv.config();

async function main() {
  const [owner, addr1] = await ethers.getSigners();

  console.log("===============================");
  console.log("Deployer address:", owner.address);

  const DEPLOYING = false // deploying or attaching to deployed contract?
  const POST_DEPLOY_ACTIONS = false // deploying or attaching to deployed contract?
  const ADD_TO_TENDERLY = false // add contracts to tenderly
  const VAULT_DEPOSIT = false
  const VAULT_INITIAL_DEPOSIT_TRANSFER = false
  const VAULT_WITHDRAW = false
  const VAULT_REBALANCE = false
  const VAULT_COMPOUND = false
  const VAULT_STATUS = true

  let GMXVault;
  let GMXTrove;
  let GMXCallback;
  let name
  let symbol

  if (DEPLOYING) {
    // =============================================
    // CONFIGURE STRATEGY VAULT TO BE DEPLOYED HERE
    // =============================================
    const LEVERAGE = 3 // 3 || 5
    const DELTA = 'Neutral' // 'Long' || 'Neutral'
    const TOKEN_A = 'ARB' // 'ETH' || 'WBTC' || 'ARB' || 'LINK'
    const TOKEN_B = 'USDC' // 'USDC'
    // =============================================
    // =============================================
    // =============================================

    /* Deploy Vault Libraries */

    let GMXReader;
    let GMXCompound;
    let GMXDeposit;
    let GMXWithdraw;
    let GMXRebalance;
    let GMXEmergency;

    console.log("Deploying vault...");

    name = `${LEVERAGE}x ${DELTA} ${TOKEN_A}-${TOKEN_B} GMX`
    symbol = `${LEVERAGE}${DELTA[0]}-${TOKEN_A}${TOKEN_B}-GMX`

    const leverage = ethers.parseUnits(LEVERAGE.toString(), 18)
    let delta // 0: Neutral, 1: Long

    if (DELTA === 'Long') delta = 1
    else if (DELTA === 'Neutral') delta = 0

    const feePerSecond = ethers.parseUnits('0', 18)
    const treasury = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.TREASURY
    const minSlippage = ethers.parseUnits('0.01', 4) // 1%
    const minExecutionFee = ethers.parseUnits('0.001', 18)

    let debtRatioStepThreshold
    let debtRatioUpperLimit
    let debtRatioLowerLimit
    // Note that delta limits do not matter for Long strategy
    let deltaUpperLimit
    let deltaLowerLimit

    if (LEVERAGE === 3 && DELTA === 'Long') {
      debtRatioStepThreshold = ethers.parseUnits('0.08', 4)
      debtRatioUpperLimit = ethers.parseUnits('0.69', 18)
      debtRatioLowerLimit = ethers.parseUnits('0.63', 18)
      deltaUpperLimit = ethers.parseUnits('0', 18)
      deltaLowerLimit = ethers.parseUnits('0', 18)
    }
    else if (LEVERAGE === 3 && DELTA === 'Neutral') {
      debtRatioStepThreshold = ethers.parseUnits('0.12', 4)
      debtRatioUpperLimit = ethers.parseUnits('0.69', 18)
      debtRatioLowerLimit = ethers.parseUnits('0.61', 18)
      deltaUpperLimit = ethers.parseUnits('0.15', 18)
      deltaLowerLimit = ethers.parseUnits('-0.15', 18)
    }
    else if (LEVERAGE === 5 && DELTA === 'Long') {
      debtRatioStepThreshold = ethers.parseUnits('0.08', 4)
      debtRatioUpperLimit = ethers.parseUnits('0.83', 18)
      debtRatioLowerLimit = ethers.parseUnits('0.77', 18)
      deltaUpperLimit = ethers.parseUnits('0', 18)
      deltaLowerLimit = ethers.parseUnits('0', 18)
    }
    else if (LEVERAGE === 5 && DELTA === 'Neutral') {
      debtRatioStepThreshold = ethers.parseUnits('0.12', 4)
      debtRatioUpperLimit = ethers.parseUnits('0.83', 18)
      debtRatioLowerLimit = ethers.parseUnits('0.75', 18)
      deltaUpperLimit = ethers.parseUnits('0.15', 18)
      deltaLowerLimit = ethers.parseUnits('-0.15', 18)
    }

    let tokenA
    let tokenB
    let lpToken
    const WNT = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WNT
    let tokenALendingVault
    let tokenBLendingVault

    if (TOKEN_A === 'ETH' && TOKEN_B === 'USDC') {
      tokenA = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH
      tokenB = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC
      lpToken = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.GMX_ETH_USDC_GM
      tokenALendingVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_ETH_ETHUSDC_GMX
      tokenBLendingVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_USDC_ETHUSDC_GMX
    }
    else if (TOKEN_A === 'WBTC' && TOKEN_B === 'USDC') {
      tokenA = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WBTC
      tokenB = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC
      lpToken = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.GMX_WBTC_USDC_GM
      tokenALendingVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_WBTC_WBTCUSDC_GMX
      tokenBLendingVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_USDC_WBTCUSDC_GMX
    }
    else if (TOKEN_A === 'ARB' && TOKEN_B === 'USDC') {
      tokenA = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB
      tokenB = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC
      lpToken = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.GMX_ARB_USDC_GM
      tokenALendingVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_ARB_ARBUSDC_GMX
      tokenBLendingVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_USDC_ARBUSDC_GMX
    }
    else if (TOKEN_A === 'LINK' && TOKEN_B === 'USDC') {
      tokenA = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.LINK
      tokenB = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC
      lpToken = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.GMX_LINK_USDC_GM
      tokenALendingVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_LINK_LINKUSDC_GMX
      tokenBLendingVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_USDC_LINKUSDC_GMX
    }

    const vault = ethers.ZeroAddress
    const trove = ethers.ZeroAddress // Trove contract will be created by Vault
    const callback = ethers.ZeroAddress // Callback contract will be created by Vault

    const chainlinkOracle = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.CHAINLINK_ORACLE
    const gmxOracle = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_ORACLE

    const exchangeRouter = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_EXCHANGE_ROUTER
    const router = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_ROUTER
    const depositVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_DEPOSIT_VAULT
    const withdrawalVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_WITHDRAWAL_VAULT
    // const orderVault = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_ORDER_VAULT
    const roleStore = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_ROLE_STORE
    // Note: We use Uniswap to swap for Arbitrum
    const swapRouter = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.SWAP_UNISWAP

    const status = 0 // Closed, will be set to Open by Vault

    const lastFeeCollected = ethers.parseUnits('0', 1)

    const refundee = ethers.ZeroAddress

    const depositCache = {
      user: ethers.ZeroAddress,
      depositValue: ethers.parseUnits('0', 1),
      sharesToUser: ethers.parseUnits('0', 1),
      depositKey: ethers.ZeroHash,
      withdrawKey: ethers.ZeroHash,
      depositParams: {
        token: ethers.ZeroAddress,
        amt: ethers.parseUnits('0', 1),
        minSharesAmt: ethers.parseUnits('0', 1),
        slippage: ethers.parseUnits('0', 1),
        executionFee: ethers.parseUnits('0', 1),
      },
      borrowParams: {
        borrowTokenAAmt: ethers.parseUnits('0', 1),
        borrowTokenBAmt: ethers.parseUnits('0', 1),
      },
      healthParams: {
        equityBefore: ethers.parseUnits('0', 1),
        debtRatioBefore: ethers.parseUnits('0', 1),
        deltaBefore: ethers.parseUnits('0', 1),
        lpAmtBefore: ethers.parseUnits('0', 1),
        equityAfter: ethers.parseUnits('0', 1),
        svTokenValueBefore: ethers.parseUnits('0', 1),
        svTokenValueAfter: ethers.parseUnits('0', 1),
      },
    }

    const withdrawCache = {
      user: ethers.ZeroAddress,
      shareRatio: ethers.parseUnits('0', 1),
      lpAmt: ethers.parseUnits('0', 1),
      withdrawValue: ethers.parseUnits('0', 1),
      tokensToUser: ethers.parseUnits('0', 1),
      withdrawKey: ethers.ZeroHash,
      depositKey: ethers.ZeroHash,
      withdrawParams: {
        shareAmt: ethers.parseUnits('0', 1),
        token: ethers.ZeroAddress,
        minWithdrawTokenAmt: ethers.parseUnits('0', 1),
        slippage: ethers.parseUnits('0', 1),
        executionFee: ethers.parseUnits('0', 1),
      },
      repayParams: {
        repayTokenAAmt: ethers.parseUnits('0', 1),
        repayTokenBAmt: ethers.parseUnits('0', 1),
      },
      healthParams: {
        equityBefore: ethers.parseUnits('0', 1),
        debtRatioBefore: ethers.parseUnits('0', 1),
        deltaBefore: ethers.parseUnits('0', 1),
        lpAmtBefore: ethers.parseUnits('0', 1),
        equityAfter: ethers.parseUnits('0', 1),
        svTokenValueBefore: ethers.parseUnits('0', 1),
        svTokenValueAfter: ethers.parseUnits('0', 1),
      },
    };

    const rebalanceCache = {
      rebalanceType: 0,
      depositKey: ethers.ZeroHash,
      withdrawKey: ethers.ZeroHash,
      borrowParams: {
        borrowTokenAAmt: ethers.parseUnits('0', 1),
        borrowTokenBAmt: ethers.parseUnits('0', 1)
      },
      healthParams: {
        equityBefore: ethers.parseUnits('0', 1),
        debtRatioBefore: ethers.parseUnits('0', 1),
        deltaBefore: ethers.parseUnits('0', 1),
        lpAmtBefore: ethers.parseUnits('0', 1),
        equityAfter: ethers.parseUnits('0', 1),
        svTokenValueBefore: ethers.parseUnits('0', 1),
        svTokenValueAfter: ethers.parseUnits('0', 1),
      },
    }

    const compoundCache = {
      depositValue: ethers.parseUnits('0', 1),
      depositKey: ethers.ZeroHash,
      compoundParams: {
        tokenIn: ethers.ZeroAddress,
        tokenOut: ethers.ZeroAddress,
        slippage: ethers.parseUnits('0', 1),
        executionFee: ethers.parseUnits('0', 1),
        deadline: ethers.parseUnits('0', 1),
      }
    }

    const storeArguments = {
      status,
      lastFeeCollected,
      refundee,
      leverage,
      delta,
      feePerSecond,
      treasury,
      debtRatioStepThreshold,
      debtRatioUpperLimit,
      debtRatioLowerLimit,
      deltaUpperLimit,
      deltaLowerLimit,
      minSlippage,
      minExecutionFee,
      tokenA,
      tokenB,
      lpToken,
      WNT,
      tokenALendingVault,
      tokenBLendingVault,
      vault,
      trove,
      callback,
      chainlinkOracle,
      gmxOracle,
      exchangeRouter,
      router,
      depositVault,
      withdrawalVault,
      roleStore,
      swapRouter,
      depositCache,
      withdrawCache,
      rebalanceCache,
      compoundCache,
    }

    const constructorArguments = [
      name,
      symbol,
      storeArguments
    ]

    GMXReader = await ethers.getContractAt(
      'GMXReader',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_GMX_READER
    )
    GMXCompound = await ethers.getContractAt(
      'GMXCompound',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_GMX_COMPOUND
    )
    GMXDeposit = await ethers.getContractAt(
      'GMXDeposit',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_GMX_DEPOSIT
    )
    GMXWithdraw = await ethers.getContractAt(
      'GMXWithdraw',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_GMX_WITHDRAW
    )
    GMXRebalance = await ethers.getContractAt(
      'GMXRebalance',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_GMX_REBALANCE
    )
    GMXEmergency = await ethers.getContractAt(
      'GMXEmergency',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_GMX_EMERGENCY
    )

    GMXVault = await ethers.deployContract(
      'GMXVault',
      constructorArguments,
      {
        libraries: {
          GMXDeposit: GMXDeposit.target,
          GMXWithdraw: GMXWithdraw.target,
          GMXRebalance: GMXRebalance.target,
          GMXCompound: GMXCompound.target,
          GMXEmergency: GMXEmergency.target,
          GMXReader: GMXReader.target,
        }
      }
    );
    await GMXVault.waitForDeployment();
    console.log("GMXVault deployed to:", GMXVault.target);
    try {
      await hre.run('verify:verify', {
        address: GMXVault.target,
        contract: 'contracts/strategy/gmx/GMXVault.sol:GMXVault',
        constructorArguments: constructorArguments
      })
    } catch (error) {
      console.log(error)
    }

    GMXTrove = await ethers.deployContract(
      'GMXTrove',
      [
        GMXVault.target
      ],
      {}
    );
    await GMXTrove.waitForDeployment();
    console.log("GMXTrove deployed to:", GMXTrove.target);
    try {
      await hre.run('verify:verify', {
        address: GMXTrove.target,
        contract: 'contracts/strategy/gmx/GMXTrove.sol:GMXTrove',
        constructorArguments: [
          GMXVault.target
        ]
      })
    } catch (error) {
      console.log(error)
    }

    GMXCallback = await ethers.deployContract(
      'GMXCallback',
      [
        GMXVault.target
      ],
      {}
    );
    await GMXCallback.waitForDeployment();
    console.log("GMXCallback deployed to:", GMXCallback.target);
    try {
      await hre.run('verify:verify', {
        address: GMXCallback.target,
        contract: 'contracts/strategy/gmx/GMXCallback.sol:GMXCallback',
        constructorArguments: [
          GMXVault.target
        ]
      })
    } catch (error) {
      console.log(error)
    }

    console.log('======================');
    console.log('Contract Addresses');
    console.log('======================');
    console.log(' ');
    console.log(`STRATEGY_3N_ETHUSDC_GMX_VAULT: '${GMXVault.target}',`)
    console.log(' ');
    console.log('======================');
  } else {
    GMXVault = await ethers.getContractAt(
      'GMXVault',
      // CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_3N_ETHUSDC_GMX_VAULT
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_3N_ARBUSDC_GMX_VAULT
    );
  }

  if (POST_DEPLOY_ACTIONS) {
    console.log('======================');
    console.log('Post deployment action');
    console.log('======================');

    console.log('Add Trove contract to vault');
    await GMXVault.connect(owner).updateTrove(
      GMXTrove.target
    );

    console.log('Add Callback contract to vault');
    await GMXVault.connect(owner).updateCallback(
      GMXCallback.target
    );

    console.log('Approve callback address for keeper');
    await GMXVault.connect(owner).updateKeeper(
      GMXCallback.target,
      true
    );

    console.log('Approve owner address for keeper');
    await GMXVault.connect(owner).updateKeeper(
      owner.address,
      true
    );

    console.log('Approve keeper address for keeper');
    await GMXVault.connect(owner).updateKeeper(
      CONSTANTS.CHAIN_ID[42161].KEEPER_ADDRESSES.DEFENDER_RELAYER,
      true
    );

    // TODO: Approve correct lending vaults
    console.log('Approve strategy vault as borrower on USDC lending pool');
    const usdcLendingVault = await ethers.getContractAt(
      'LendingVault',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_USDC_ARBUSDC_GMX
    );
    await usdcLendingVault.connect(owner).approveBorrower(GMXVault.target);

    console.log('Approve strategy vault as borrower on ARB lending pool');
    const wethLendingVault = await ethers.getContractAt(
      'LendingVault',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_ARB_ARBUSDC_GMX
    );
    await wethLendingVault.connect(owner).approveBorrower(GMXVault.target);

    // console.log('Approve owner USDC allowance for strategy vault');
    // const USDCToken = await ethers.getContractAt(
    //   'ERC20',
    //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC
    // );
    // await USDCToken.connect(owner).approve(
    //   GMXVault.target,
    //   ethers.parseUnits('50', 6)
    // );

    // console.log('Approve owner WETH allowance for strategy vault');
    // const WETHToken = await ethers.getContractAt(
    //   'ERC20',
    //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH
    // );
    // await WETHToken.connect(owner).approve(
    //   GMXVault.target,
    //   ethers.parseUnits('0.03', 18)
    // );

    // console.log('Approve owner GM allowance for strategy vault');
    // const GMToken = await ethers.getContractAt(
    //   'ERC20',
    //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.GMX_ETH_USDC_GM
    // );
    // await GMToken.connect(owner).approve(
    //   GMXVault.target,
    //   ethers.parseUnits('10', 18)
    // );

    // console.log('Approve strategy vault as borrower on USDC lending pool');
    // const usdcLendingVault = await ethers.getContractAt(
    //   'LendingVault',
    //   CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_USDC_ETHUSDC_GMX
    // );
    // await usdcLendingVault.connect(owner).approveBorrower(GMXVault.target);

    // console.log('Approve strategy vault as borrower on WETH lending pool');
    // const wethLendingVault = await ethers.getContractAt(
    //   'LendingVault',
    //   CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_ETH_ETHUSDC_GMX
    // );
    // await wethLendingVault.connect(owner).approveBorrower(GMXVault.target);
  }

  if (ADD_TO_TENDERLY) {
    const contracts = [
      {
        display_name: symbol,
        address: GMXVault.target,
        network_id: '42161'
      },
      {
        display_name: `${symbol} Trove`,
        address: GMXTrove.target,
        network_id: '42161'
      },
      {
        display_name: `${symbol} Callback`,
        address: GMXCallback.target,
        network_id: '42161'
      },
    ]

    run(contracts);
  }

  if (VAULT_DEPOSIT) {
    console.log('Deposit $0.10 USDC into strategy vault');
    await GMXVault.connect(owner).deposit(
      {
        token: CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
        amt: ethers.parseUnits('0.1', 6),
        minSharesAmt: ethers.parseUnits('0', 18),
        slippage: ethers.parseUnits('0.01', 4),
        executionFee: ethers.parseUnits('0.001', 18)
      },
      { value: ethers.parseUnits('0.001', 18) }
    );

    // await GMXVault.connect(owner).depositNative(
    //   {
    //     token: CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
    //     amt: ethers.parseUnits('0.001', 18),
    //     minSharesAmt: ethers.parseUnits('0', 18),
    //     slippage: ethers.parseUnits('0.01', 4),
    //     executionFee: ethers.parseUnits('0.001', 18)
    //   },
    //   { value: ethers.parseUnits('0.002', 18) }
    // );
  }

  if (VAULT_INITIAL_DEPOSIT_TRANSFER) {
    console.log('Transfer initial deposit to vault to prevent vault inflation attacks');
    const GMXVaultToken = await ethers.getContractAt(
      'ERC20',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.STRATEGY_3N_ARBUSDC_GMX_VAULT
    );
  }

  if (VAULT_WITHDRAW) {
    console.log('Withdraw from strategy vault');
    await GMXVault.connect(owner).withdraw(
      {
        shareAmt: ethers.parseUnits('0.04', 18),
        token: CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
        minWithdrawTokenAmt: ethers.parseUnits('0', 18),
        slippage: ethers.parseUnits('0.01', 4),
        executionFee: ethers.parseUnits('0.001', 18)
      },
      { value: ethers.parseUnits('0.001', 18) }
    );
  }

  if (VAULT_REBALANCE) {
    // console.log('Rebalance Add')
    // await GMXVault.connect(owner).rebalanceAdd(
    //   {
    //     rebalanceType: 0, // 0: Delta, 1: Debt
    //     borrowParams: {
    //       borrowTokenAAmt: ethers.parseUnits('0.000228245', 18),
    //       borrowTokenBAmt: ethers.parseUnits('0', 6),
    //     },
    //     slippage: ethers.parseUnits('0.01', 4),
    //     executionFee: ethers.parseUnits('0.001', 18)
    //   },
    //   { value: ethers.parseUnits('0.001', 18) }
    // )

    // NOTE: Should remove a little more LP for rebalance down
    console.log('Rebalance Remove')
    await GMXVault.connect(owner).rebalanceRemove(
      {
        rebalanceType: 0, // 0: Delta, 1: Debt
        lpAmtToRemove: ethers.parseUnits('0.5183618286', 18),
        slippage: ethers.parseUnits('0.01', 4),
        executionFee: ethers.parseUnits('0.001', 18)
      },
      { value: ethers.parseUnits('0.001', 18) }
    )
  }

  if (VAULT_COMPOUND) {
    console.log('Transfer ARB to strategy vault');
    const ARBToken = await ethers.getContractAt(
      'ERC20',
      CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB
    );
    await ARBToken.connect(owner).transfer(
      GMXVault.target,
      ethers.parseUnits('0.1', 18)
    );

    console.log('Compound')
    const deadline = Math.floor(Date.now() / 1000) + 60
    await GMXVault.connect(owner).compound(
      {
        tokenIn: CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB,
        tokenOut: CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
        slippage: ethers.parseUnits('0.01', 4),
        executionFee: ethers.parseUnits('0.001', 18),
        deadline: deadline,
      },
      { value: ethers.parseUnits('0.001', 18) }
    )
  }

  if (VAULT_STATUS) {
    const chainlinkOracle = await ethers.getContractAt(
      'ChainlinkARBOracle',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.CHAINLINK_ORACLE
    )
    const gmxOracle = await ethers.getContractAt(
      'GMXOracle',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_ORACLE
    )
    const store = await GMXVault.connect(owner).store();

    const currentDebtValue = await GMXVault.debtValue()
    const currentDebtValues = currentDebtValue[0] + currentDebtValue[1]
    const equityValue = await GMXVault.equityValue()
    const targetDebtValue = equityValue * 2n

    let diffDebtValue = 0n
    if (currentDebtValues >= targetDebtValue) {
      // Repay
      diffDebtValue = currentDebtValues - targetDebtValue
    } else {
      // Borrow
      diffDebtValue = targetDebtValue - currentDebtValues
    }

    const currentDeltaValue = await GMXVault.delta()
    const targetDeltaValue = 0n

    let diffDeltaValue = 0n
    if (currentDeltaValue >= targetDeltaValue) {
      // Borrow more tokenA to reduce this delta diff
      diffDeltaValue = currentDeltaValue - targetDeltaValue
    } else {
      // Repay more tokenA to reduce this delta diff
      diffDeltaValue = targetDeltaValue - currentDeltaValue
    }

    const DATA: any = {}

    DATA['ETH Price'] = ethers.formatUnits(await chainlinkOracle.consultIn18Decimals(
      CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH
    ), 18)
    DATA['ETH-USDC GM Price'] = ethers.formatUnits(await gmxOracle.getLpTokenValue(
      CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.GMX_ETH_USDC_GM,
      CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
      CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
      CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
      false,
      false
    ), 18)
    DATA['svToken Total Supply'] = ethers.formatUnits(await GMXVault.totalSupply(), 18)
    DATA['svToken Owner Balance'] = ethers.formatUnits(await GMXVault.balanceOf(owner), 18)
    DATA['Status'] = store.status
    DATA['Current Leverage'] = ethers.formatUnits(await GMXVault.leverage(), 18)
    // DATA['Current Delta'] = await GMXVault.delta()
    DATA['Current Delta'] = ethers.formatUnits(await GMXVault.delta(), 18)
    DATA['Current Debt Ratio'] = ethers.formatUnits(await GMXVault.debtRatio(), 18)
    DATA['Current Asset Value'] = ethers.formatUnits(await GMXVault.assetValue(), 18)
    DATA['Current Debt Value'] = ethers.formatUnits(currentDebtValues, 18)
    DATA['Current Debt Value TokenA'] = ethers.formatUnits(currentDebtValue[0], 18)
    DATA['Current Debt Value TokenB'] = ethers.formatUnits(currentDebtValue[1], 18)
    DATA['Current Equity Value'] = ethers.formatUnits(await GMXVault.equityValue(), 18)
    DATA['Target Debt Value'] = ethers.formatUnits(targetDebtValue, 18)
    DATA['Target Delta'] = ethers.formatUnits(targetDeltaValue, 18)
    DATA['Diff Debt Value'] = ethers.formatUnits(diffDebtValue, 18)
    DATA['Diff Delta'] = ethers.formatUnits(diffDeltaValue, 18)
    DATA['svTokenValue'] = ethers.formatUnits(await GMXVault.svTokenValue(), 18)
    DATA['Delta Lower Limit'] = ethers.formatUnits(store.deltaLowerLimit, 18)
    DATA['Asset Amt TokenA'] = ethers.formatUnits((await GMXVault.assetAmt())[0], 18)
    DATA['Asset Amt TokenB'] = ethers.formatUnits((await GMXVault.assetAmt())[1], 6)
    DATA['Debt Amt TokenA'] = ethers.formatUnits((await GMXVault.debtAmt())[0], 18)
    DATA['Debt Amt TokenB'] = ethers.formatUnits((await GMXVault.debtAmt())[1], 6)

    console.table(DATA)
  }

  console.log("===============================");
}

async function sleep(millis: number) {
  return new Promise(resolve => setTimeout(resolve, millis));
}

async function run(contracts: object[]) {
  for (let i = 0; i < contracts.length; i++) {
    await sleep(2000);
    console.log('Add contract')
    addContract(contracts[i]);
  }

  function addContract(contract: object) {
    const options = {
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'insomnia/2023.5.8',
        Authorization: process.env.TENDERLY_ACCOUNT_AUTH_TOKEN
      },
      body: contract,
      json: true
    };

    const URI: string = process.env.TENDERLY_ACCOUNT_URL ? process.env.TENDERLY_ACCOUNT_URL : '';
    request.post(URI, options, () => {
      console.log('Added contract to tenderly');
    })
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
