# Technical Documentation
More explanation of technical diagrams and flows here.

# Table of Contents
- [Protocol Overview](#protocol-overview)
  - [Actors](#actors)
  - [Strategy Vaults](#strategy-vaults)
    - [Delta Long](#delta-long)
    - [Delta Neutral](#delta-neutral)
    - [Automated Rebalancing](#automated-rebalancing)
  - [Lending Vaults](#lending-vaults)
    - [Profit Sharing Rates](#profit-sharing-rates)
- [Technical Overview](#technical-overview)
  - [High Level System Architecture](#high-level-system-architecture)
- [Lending Vault Technical Overview](#lending-vault-technical-overview)
  - [Lending Vault Class Diagram](#lending-vault-class-diagram)
  - [Lending Vault Actions](#lending-vault-actions)
- [Strategy Vault Technical Overview](#strategy-vault-technical-overview)
  - [Strategy Vault Class Diagram](#strategy-vault-class-diagram)
  - [Strategy Vault Actions](#strategy-vault-actions)
  - [Strategy Vault Sequence Diagrams](#strategy-vault-sequence-diagrams)
    - [Strategy Vault Deposit Sequence Flow](#strategy-vault-deposit-sequence-flow)
    - [Strategy Vault Withdraw Sequence Flow](#strategy-vault-withdraw-sequence-flow)
    - [Strategy Vault Rebalance Add Sequence Flow](#strategy-vault-rebalance-add-sequence-flow)
    - [Strategy Vault Rebalance Remove Sequence Flow](#strategy-vault-rebalance-remove-sequence-flow)
    - [Strategy Vault Compound Sequence Flow](#strategy-vault-compound-sequence-flow)
    - [Strategy Vault Emergency Sequence Flow](#strategy-vault-emergency-sequence-flow)

# Protocol Overview
There are 2 types of vaults: **Lending Vaults** and **Strategy Vaults**.

A typical set up for 3x Leverage, Delta Long and Delta Neutral strategies to the ETH-USDC GM LP pool on GMXv2, with isolated ETH and USDC lending vaults are as follows:

```mermaid
graph TD
  SVL["3x Long ETH-USDC GMX"]
  SVN["3x Neutral ETH-USDC GMX"]
  LVE["ETH Lending Vault"]
  LVU["USDC Lending Vault"]
  L(("Lender"))
  D(("Depositor"))

  style SVL fill:blue,stroke:blue,color:white
  style SVN fill:blue,stroke:blue,color:white
  style LVE fill:blue,stroke:blue,color:white
  style LVU fill:blue,stroke:blue,color:white
  style L fill:green,stroke:green,color:white
  style D fill:green,stroke:green,color:white

  D <--->|Deposit/Withdraw ETH/USDC/ETH-USDC LP| SVL
  D <--->|Deposit/Withdraw ETH/USDC/ETH-USDC LP| SVN

  SVL <--->|Borrow/Repay USDC for Leverage| LVU
  SVN <--->|Borrow/Repay USDC for Leverage| LVU
  SVN <--->|Borrow/Repay ETH for Delta Hedging| LVE

  LVE <--->|Deposit/Withdraw ETH| L
  LVU <--->|Deposit/Withdraw USDC| L
```

> Note that Delta Long strategies borrow only USDC for more leverage, while Delta Neutral strategies borrow both USDC for leverage **as well as** borrow ETH in order to delta hedge the ETH exposure of the liquidity provided to the ETH-USDC GM LP pool (borrowing = hedging).

### Steadefi Front-End Interface Screenshot
![Lending and Strategy Vaults Setup](./img/lending-strategy-vaults-screenshot.png)


## Actors
| Role | Responsibilities |
| ------ | --------------- |
| Lender | Lenders deposit assets to Lending Vaults (1 asset per Lending Vault) to earn safer, more stable borrow interest on their assets. |
| Depositor | Depositors deposit assets to Strategy Vaults (Strategy Vaults could accept different assets) to earn earn higher yields than if they were to supply their assets to the yield-earning protocol directly. Depending on the strategy however, they take on different types of risk which would affect their final profit and losses. |
| Keeper | Keepers are automated "bots" that run 24/7, frequently scheduled and/or event-triggered code scripts to perform various protocol maintainence tasks. These tasks include updating of borrow interest rates for Lending Vaults, rebalancing Strategy Vaults whose health are out of its' strategy parameter limits, compounding earned yield for Strategy Vaults, reverting certain issues for strategy vaults when they occur and triggering Emergency Pauses for lending and strategy vaults in the event of any possible issues. |
| Owner | Owner are administrators that have rights to configure and update various sensitive vault configurations and parameters. Owners of deployed smart-contracts (vaults, oracles, etc.) should be Timelocks of which are managed by Multi-Sigs that require at least a 2 out of 3 signing approval for any transactions to happen with a 24 hours delay. Note that on contract deployment, the immediate Owner is the hot wallet deployer account. After deploying and initial configuration of the contract, the ownership should be immediately transferred from the hot wallet deployer to a Timelock managed by a Multi-Sig. |


## Strategy Vaults
**Strategy vaults** are multi-asset vaults that carry out a particular yield-earning strategy via taking on under-collaterised borrowing from lending vaults. Strategy vaults earn yield by collecting fees by providing its' assets to external protocols for usage, typically in the form of swap/trading/lending/staking liqudity.

**Strategy vaults** can vary by:
- Leverage (3x, 5x, etc.)
- Delta (Delta Long or Delta Neutral to the underlying volatile asset(s))
- Yield Source(s) (Usually by providing liqudiity to Automated Market Makers, Perpetual Exchanges, Liquid Staking)
- Underlying Assets (ETH, WBTC, USDC, etc.)

> *Delta refers to the directional risk associated with the price movements of an underlying asset.*

### Delta Long
A Delta Long strategy (also known as Delta 1) means that the USD value of your position would be directly correlated with the price movement of an underlying asset (i.e. if the asset's price increases, your position value should also increase, and vice versa).

Example:
1) Price of ETH is USD $1000 and price of 1 USDC is USD $1. The value of a ETH-USDC LP token with 50% token weight in ETH and 50% in USDC is USD $1.
2) A depositor deposits 1 USDC (equity value) to a 3x Long ETH-USDC strategy vault, which borrows 2 USDC (debt value) for a total of 3 USDC (asset value), which it then adds liquidity for 3 ETH-USDC LP tokens.
3a) If the price of ETH increases 50% to USD $1500, the value of the ETH-USDC LP token should increase by 25% to $1.25. The asset value of the vault would be $3.75, the debt value still remains at $2 and the equity value is $1.75 (asset - debt), effectively earning a 75% return on equity before paying borrow interest or accounting for earned yield.
3b) If the price of ETH decreases 50% to USD $500, the value of the ETH-USDC LP token should decrease by 25% to $0.75. The asset value of the vault would be $2.25, the debt value still remains at $2 and the equity value is $0.25 (asset - debt), effectively losing 75% on equity before paying borrow interest or accounting for earned yield.

> *If you hold the belief that the price of the volatile asset is mostly going up over time, it is more beneficial to deposit in a Leveraged Delta Long strategy.*

### Delta Neutral
A Delta Neutral strategy (also known as Delta 0) means that the USD value of your position value is not directly correlated with the price movement of an underlying asset (i.e. if the asset's price increases OR decreases, your position value does not increase OR decrease as significantly as the price changes both-ways are hedged).

Example:
1) Price of ETH is USD $1000 and price of 1 USDC is USD $1. The value of a ETH-USDC LP token with 50% token weight in ETH and 50% in USDC is USD $1.
2) A depositor deposits 1 USDC (equity value) to a 3x Neutral ETH-USDC strategy vault, which borrows $1.50 USD worth of ETH (to hedge out the total ETH amount of $1.50 in the final $3 asset value position) and 0.50 USDC (for a combined debt value of $2) for a total of 3 USD worth of assets (asset value), which it then adds liquidity for 3 ETH-USDC LP tokens.
3a) If the price of ETH increases 50% to USD $1500, the value of the ETH-USDC LP token should increase by 25% to $1.25. The asset value of the vault would be $3.75, the debt value would be $2.375 ($1.50 -> $1.875 ETH + $0.50 USDC) and the equity value is $1.375 (asset - debt), effectively earning a 37.5% return on equity before paying borrow interest or accounting for earned yield.
3b) If the price of ETH decreases 50% to USD $500, the value of the ETH-USDC LP token should decrease by 25% to $0.75. The asset value of the vault would be $2.25, the debt value will decrease to $1.25 ($1.50 -> $0.75 ETH + $0.50 USDC) and the equity value is $1 (asset - debt), effectively having a 0%  gain/loss on equity before paying borrow interest or accounting for earned yield. In this scenario, if the yield earned is higher than the borrow interest, the depositor will make a positive return despite the price of ETH decreasing by 50%.

> *If you hold the belief that the price of the volatile asset is going to stay within a range (crabbish) or perhaps would even decrease slightly over time, it is more beneficial to deposit in a Leveraged Delta Neutral strategy.*

**Depositors** can deposit accepted assets into strategy vaults in exchange for shares of the **Strategy Vault (svToken)**.

**Keepers** regularly check and maintain every vault's target leverage and delta strategy. This means that depositors to these strategy vaults do not have to manually manage their own position's strategy.

The benefits to Depositors are:
- Earn higher yields due to under-collaterised borrowing with the same amount of assets owned
- 24/7 automated strategy rebalancing instead of manual rebalancing
- No liquidation
- Auto-compounding of yields earned
- No negative yield (i.e. no risk of borrow rates being higher than yield earning rates). See *Profit Sharing Rates* section for more details.

Here is an animated screenshot showing the price charts of delta long and neutral strategies. The bright green line is the value of a vault token share (svTokenValue), while the other coloured lines are referencing the price changes of the underlying assets (in the case of GLP, it consists of mainly BTC, ETH and USD stablecoins):

![Price chart of Delta Long and Delta Neutral Strategy](https://steadefi.com/landing/3LN-GLP.gif)

### Automated Rebalancing
A leverage delta strategy will change over time due to changes in the volatile asset price, borrow interest rates and yield earning rates.

This results in a strategy's debt ratio and/or delta to possibly "drift" too far from it's intended target leverage and delta strategy. Depending on how things play out, such drifts "away" from the intended target strategy could also back to it's target (good), but could also drift even further (not good as it is not executing on its intended strategy).

As such, constant maintainence of a vault's strategy should be adhered to in order to keep its integrity over a period of time to allow for a safer and more reliable yield earning strategy.

Steadefi strategy vaults have min/max parameters for debt ratio and delta. Keepers will constantly check if the strategy vaults have exceeded these parameters, and if so, automatically trigger a rebalance such that the vault's debt ratio and delta is reset back to it's intended target leverage and delta hedge.

Note that the intention is not to over-rebalance, as every rebalance incurs a cost to the strategy vault. As such, the parameters set for every vault in order to determine when a vault should rebalance comes from the team's quant research and experience on a best effort basis, and depending on market conditions, may be updated over time.

## Lending Vaults
Lending vaults are single asset vaults that lend out its' assets to strategy vaults to allow strategy vaults to carry out their intended strategy. Lending vaults's yield come from charging interest to strategy vaults for assets borrowed.

Steadefi implements **Isolated Lending Vaults** to cater to different strategy vaults. Although this fragments lending asset liquidity (e.g. there can be mutliple USDC Lending Vaults), this further isolates risks to both Lenders and Depositors, and allow Lenders to more granularly decide the yield (and corresponding risk) of their assets being lent out to strategies.

> *If a user simply wants to reliably accumulate more of an asset without concern of the USD value of the asset over time, while looking for a more stable, reliable return profile, it is more beneficial to lend out assets in a Lending Vault.*

**Lenders** can deposit individual assets to **Lending Vaults** in exchange for shares of the **Lending Vault (lvToken)**.

The benefits to Lenders are:
- Earn safer and more stable yield in the form of the asset being lent out
- No exposure to impermanent loss

**Keepers** regularly check and update every lending vault's borrow interest rates based on the Yield APR of the strategy vault's that is borrowing assets from it. See *Profit Sharing Rates* section for more details.


### Profit Sharing Rates
Most existing DeFi Lending Vaults uses a Utilization Rate model to determine their borrow rates.

For borrowers (strategy vaults), the largest concern with the “utilization rate” system is the potential negative APRs on their position. In this case, the borrowing rates would be higher than their yields, effectively putting them in a losing position until more lending funds are deposited or borrowers reduce their position. As it does not make sense for borrowers to have negative yield, such situations may ultimately reduce the demand for borrows in the long-run, which overall reduces the interest earned to lenders.

For lenders (lending vaults), the returns they receive are limited by a linear model that is based entirely on the “utilization rate”. This means that lenders make significant yields on their deposits when borrowing is high, and likewise they earn very little yield when borrowing is low.

Steadefi implements a Profit Sharing Model that aim to address the above issues by adjusting the borrow rates charged by lenders based on the Yield APRs being earned by borrowers:
- When Yield APRs are high for Strategy Vaults, Borrow Interest is increased by Lenders
- When Yield APRs are low for Strategy Vaults, Borrow Interest is decreased by Lenders

The adjustment is done by automated **Keepers**.

This effectively results in a "profit sharing" situation, where lenders stand to earn higher returns when yields are high for strategy vaults (beneficial to lenders) but may also earn lower returns when yields are low for strategy vaults (beneficial to strategy vaults, which keeps them borrowing for longer rather than leaving).

<br>

# Technical Overview
Here is a high level technical architecture that shows the various components (smart-contracts, external protocols, keepers, back-end infrastructure, etc.) and how they interact with each other.

Steadefi runs a centralised CRON service and Back-End API to obtain vaults' data, and stores them in a centralised Database. This data is used for displaying the historical charts of the vault on Steadefi's front-end interface.

Keepers (using OpenZeppelin Defender Relayers and Autotasks) are also ran that performs tasks such as adjusting the borrow rates of lending vaults as well as compounding and rebalancing strategy vaults (when needed).

*(Not shown in graph)* All smart contracts are owned by a Timelock, of which it is controlled by a Multi-Sig with at least 2 out of 3 signers required for owner-only changes. Signers are hardware wallets of diferent individuals of the Steadefi team.

## High Level System Architecture

```mermaid
---
title: Steadefi High Level System Architecture
---
graph TD
  CPF[["Chainlink Price Feeds"]]
  P[["Protocol (Yield Source e.g. GMX)"]]
  CO["Chainlink Oracle"]
  PO["Protocol Oracle"]
  SV["Strategy Vault"]
  LV["Lending Vault"]
  K("Keeper")
  CR("CRON")
  DB[("Database")]
  SW["Protocol Swap"]
  AMM[["AMM e.g. Uniswap"]]
  U(("User"))

  style SV fill:blue,stroke:blue,color:white
  style LV fill:blue,stroke:blue,color:white
  style PO fill:blue,stroke:blue,color:white
  style SW fill:blue,stroke:blue,color:white
  style CO fill:blue,stroke:blue,color:white
  style U fill:green,stroke:green,color:white
  style P fill:brown,stroke:brown,color:white
  style CPF fill:brown,stroke:brown,color:white
  style AMM fill:brown,stroke:brown,color:white
  style CR fill:navy,stroke:navy,color:white
  style K fill:navy,stroke:navy,color:white
  style DB fill:navy,stroke:navy,color:white

  U <--->|Deposit/Withdraw assets| LV
  U <--->|Deposit/Withdraw assets| SV

  CO -.->|Get Asset Price| CPF

  SV <-->|Borrow/Repay assets| LV
  SV -..->|Get Asset Price| CO
  SV -..->|Get LP Price| PO
  PO -..->|Get Asset Price| CO

  SV <--->|Add/Remove Liquidity/Stake| P
  SV <-->|Swap Assets for Repay/Rebalance| SW
  SW <-->|Swap Assets| AMM

  K <-->|Update Interest Rate Model| LV
  K <-->|Compound/Rebalance/Emergency Pause/Resume/Shutdown| SV
  K -.->|Reads Data| DB

  CR -..->|Gets Data| LV
  CR -..->|Gets Data| SV
  CR --->|Updates Data| DB

```

<br>

# Lending Vault Technical Overview

## Lending Vault Class Diagram

```mermaid
---
title: Lending Vault Class Diagram
---
classDiagram
    direction LR
    class LendingVault {
        +asset
        +isNativeAsset
        +treasury
        +totalBorrows
        +totalBorrowDebt
        +performanceFee
        +vaultReserves
        +lastUpdatedAt
        +maxCapacity
        +interestRate
        +maxInterestRate

        +borrowers[]
        +keepers[]

        ~onlyBorrower()
        ~onlyKeeper()

        +totalAsset()
        +totalAvailableAsset()
        +utilizationRate()
        +lvTokenValue()
        +borrowAPR()
        +lendingAPR()
        +maxRepay()
        +depositNative()
        +deposit()
        +withdraw()
        +borrow()
        +repay()
        +withdrawReserve()

        ~_onlyBorrower()
        ~_onlyKeeper()
        ~_mintShares()
        ~_burnShares()
        ~_updateVaultWithInterestsAndTimestamp()
        ~_pendingInterest()
        ~_to18ConversionFactor()
        ~_calculateInterestRate()

        #updateInterestRate()
        #updatePerformanceFee()
        #approveBorrower()
        #revokeBorrower()
        #updateKeeper()
        #emergencyRepay()
        #emergencyShutdown()
        #emergencyResume()
        #updateMaxCapacity()
        #updateMaxInterestRate()
        #updateTreasury()

        +receive()
    }

```

## Lending Vault Actions
All actions possible to a Lending Vault and their expected outcome and impact, grouped by access to roles.

- **Owner**: The vault's initial owner is the deployer, which will be a hot wallet. Certain actions will be triggered immediately post-deployement as part of the vault's initialization and configuration. Immediately after initialization, the ownership will be transferred to a Timelock contract which is owned by a Multi-Sig that requires at least a 2/3 signing for execution of any proposed actions, with at least a 24 hour delay.
- **Keeper**: Keepers are OpenZeppelin Defender Relayer accounts that run autotasks triggered on a scheduled frequency or event that matched a set rule. In the future, keepers may be decentralized with Chainlink Automation or Gelato Keepers.
- **Vault**: An approved Steadefi strategy vault that can borrow/repay from the lending vault
- **User**: Either a depositor or a lender for the lending vault.
- **Any**: Any of the above / public.

| Role  | Action | Expected Impact |
| ----- | ------ | --------------- |
| Owner | approveBorrower | Approve a strategy vault to allow it to borrow assets |
| Owner | revokeBorrower | Revoke a strategy vault to allow it to borrow assets |
| Owner | updateKeeper | Approve or revoke an address to have "keeper" role |
| Owner | updateTreasury | Update protocol's treasury address for this vault |
| Owner | updatePerformanceFee | Update performance fee for vault |
| Owner | updateMaxCapacity | Update maximum capacity for deposits allowed for this vault |
| Owner | emergencyResume | Unpauses vault so asset deposits/withdrawals/borrows are allowed. |
| Keeper | updateInterestRate | Pauses vault so no asset deposits/withdrawals/borrows are allowed. |
| Keeper | withdrawReserve | Withdraw fees that were charged but not withdrawn from this vault |
| Keeper | emergencyShutdown | Pauses vault so no asset deposits/withdrawals/borrows are allowed. |
| Keeper | emergencyRepay | Allows keeper to repay debt for an existing borrower with debt |
| Vault | borrow | Borrow assets from this vault |
| Vault | repay | Repay assets from this vault |
| User | deposit | Deposit assets in exchange for lending vault share tokens (lvToken) |
| User | depositNative | Deposit native assets (ETH, AVAX, etc.) in exchange for lending vault share tokens (lvToken) |
| User | withdraw | Withdraw assets in exchange for lending vault share tokens (lvToken) |
| Any | totalAsset | Returns total amount of deposited assets in the lending vault |
| Any | totalAvailableAsset | Returns total amount of available assets that can be borrowed in the lending vault |
| Any | utilizationRate | Returns current total borrowed / total deposited rate |
| Any | lvTokenValue | Returns the lending vault token value: total assets / total lvToken shares |
| Any | borrowAPR | Returns current interest rate charged to borrowers |
| Any | lendingAPR | Returns current interest rate yield given to lenders |
| Any | maxRepay | Returns maximum amount repayable by a borrower

<br>

# Strategy Vault Technical Overview

## Strategy Vault Class Diagram

```mermaid
---
title: GMX Strategy Vault Class Diagram
---
classDiagram
    direction LR

    class GMXTypes {
      struct Store
      struct DepositCache
      struct WithdrawCache
      struct CompoundCache
      struct RebalanceCache
      struct DepositParams
      struct WithdrawParams
      struct CompoundParams
      struct RebalanceAddParams
      struct RebalanceRemoveParams
      struct BorrowParams
      struct RepayParams
      struct HealthParams
      struct AddLiquidityParams
      struct RemoveLiquidityParams

      enum Status
      enum Delta
      enum RebalanceType
    }

    class GMXVault {
      ~_store

      +keepers[]
      +tokens[]

      ~onlyVault()
      ~onlyKeeper()

      +store()
      +isTokenWhitelisted()
      +svTokenValue()
      +pendingFee()
      +valueToShares()
      +convertToUsdValue()
      +tokenWeights()
      +assetValue()
      +debtValue()
      +equityValue()
      +assetAmt()
      +debtAmt()
      +lpAmt()
      +leverage()
      +delta()
      +debtRatio()
      +additionalCapacity()
      +capacity()

      +deposit()
      +depositNative()
      +withdraw()
      +emergencyWithdraw()
      +mintFee()

      ~_onlyVault()
      ~_onlyKeeper()

      #processDeposit()
      #processDepositCancellation()
      #processDepositFailure()
      #processDepositFailureLiquidityWithdrawal()

      #processWithdraw()
      #processWithdrawCancellation()
      #processWithdrawFailure()
      #processWithdrawFailureLiquidityAdded()

      #rebalanceAdd()
      #processRebalanceAdd()
      #rebalanceRemove()
      #rebalanceRemoveCancellation()

      #compound()
      #processCompoundAdd()
      #processCompoundCancellation()

      #emergencyPause
      #emergencyResume
      #processEmergencyResume
      #emergencyClose

      #updateKeeper()
      #updateTreasury()
      #updateSwapRouter()
      #updateCallback()
      #updatefeePerSecond()
      #updateParameterLimits()
      #updateMinSlippage()
      #updateMinExecutionFee()

      #mint()
      #burn()

      +receive()
    }

    class GMXCallback {
      +vault
      +roleStore

      ~onlyController

      #afterDepositExecution()
      #afterDepositCancellation()
      #afterWithdrawalExecution()
      #afterWithdrawalCancellation()
    }

    class GMXDeposit {
      event DepositCreated
      event DepositCompleted
      event DepositCancelled
      event DepositFailed

      +deposit()
      +processDeposit()
      +processDepositCancellation()
      +processDepositFailure()
      +processDepositFailureLiquidityWithdrawal()
    }

    class GMXProcessDeposit {
      +processDeposit()
    }

    class GMXWithdraw {
      event WithdrawCreated
      event WithdrawCompleted
      event WithdrawCancelled
      event WithdrawFailed

      +withdraw()
      +processWithdraw()
      +processWithdrawCancellation()
      +processWithdrawFailure()
      +processWithdrawFailureLiquidityAdded()
    }

    class GMXProcessWithdraw {
      +processWithdraw()
    }

    class GMXRebalance {
      event RebalanceSuccess
      event RebalanceFailed

      +rebalanceAdd()
      +processRebalanceAdd()
      +processRebalanceAddCancellation()
      +rebalanceRemove()
      +processRebalanceRemove()
      +processRebalanceRemoveCancellation()
    }

    class GMXCompound {
      event Compound
      event CompoundFailed

      +compound()
      +processCompound()
      +processCompoundCancellation()
    }

    class GMXEmergency {
      event EmergencyPause
      event EmergencyResume
      event EmergencyClose
      event EmergencyWithdraw

      +emergencyPause()
      +emergencyResume()
      +processEmergencyResume()
      +emergencyClose()
      +emergencyWithdraw()
    }

    class GMXReader {
      +svTokenValue()
      +pendingFee()
      +valueToShares()
      +convertToUsdValue()
      +tokenWeights()
      +assetValue()
      +debtValue()
      +equityValue()
      +assetAmt()
      +debtAmt()
      +lpAmt()
      +leverage()
      +delta()
      +debtRatio()
      +additionalCapacity()
      +capacity()
    }

    class GMXManager {
      +calcSwapForRepay()
      +calcBorrow()
      +calcRepay()
      +calcMinMarketSlippageAmt()
      +calcMinTokensSlippageAmt()

      +borrow()
      +repay()
      +addLiquidity()
      +removeLiquidity()
      +swapExactTokensForTokens()
      +swapTokensForExactTokens()
    }

    class GMXChecks {
      +beforeNativeDepositChecks()
      +beforeDepositChecks()
      +beforeProcessDepositChecks()
      +afterDepositChecks()
      +beforeProcessDepositCancellationChecks()
      +beforeProcessAfterDepositFailureChecks()
      +beforeProcessAfterDepositFailureLiquidityWithdrawal()
      +beforeWithdrawChecks()
      +beforeProcessWithdrawChecks()
      +afterWithdrawChecks()
      +beforeProcessWithdrawCancellationChecks()
      +beforeProcessAfterWithdrawFailureChecks()
      +beforeProcessAfterWithdrawFailureLiquidityAdded()
      +beforeRebalanceChecks()
      +beforeProcessRebalanceChecks()
      +afterRebalanceChecks()
      +beforeCompoundChecks()
      +beforeProcessCompoundChecks()
      +beforeProcessCompoundCancellationChecks()
      +beforeEmergencyCloseChecks()
      +beforeEmergencyResumeChecks()
      +beforeProcessEmergencyResumeChecks()
      +beforeEmergencyWithdrawChecks()

      ~_isWithinStepChange()
    }

    class GMXWorker {
      +addLiquidity()
      +removeLiquidity()
      +swapExactTokensForTokens()
      +swapTokensForExactTokens()
    }

    note for GMXTypes "All contracts and libraries inherit
    Structs and Enums from GMXTypes"

    GMXCallback --> GMXVault

    GMXVault --> GMXDeposit
    GMXVault --> GMXWithdraw
    GMXVault --> GMXCompound
    GMXVault --> GMXRebalance
    GMXVault --> GMXEmergency
    GMXVault --> GMXReader

    GMXDeposit --> GMXManager
    GMXWithdraw --> GMXManager
    GMXCompound --> GMXManager
    GMXRebalance --> GMXManager
    GMXEmergency --> GMXManager

    GMXDeposit --> GMXChecks
    GMXWithdraw --> GMXChecks
    GMXCompound --> GMXChecks
    GMXRebalance --> GMXChecks
    GMXEmergency --> GMXChecks

    GMXDeposit --> GMXProcessDeposit
    GMXWithdraw --> GMXProcessWithdraw

    GMXManager --> GMXReader
    GMXManager --> GMXWorker

```

## Strategy Vault Actions
All actions possible to a Strategy Vault and their expected outcome and impact, grouped by access to roles.

- **Owner**: The vault's initial owner is the deployer, which will be a hot wallet. Certain actions will be triggered immediately post-deployement as part of the vault's initialization and configuration. Immediately after initialization, the ownership will be transferred to a Timelock contract which is owned by a Multi-Sig that requires at least a 2/3 signing for execution of any proposed actions, with at least a 24 hour delay.
- **Keeper**: Keepers can be the Vault's Callback contract or OpenZeppelin Defender Relayer accounts that run autotasks triggered on a scheduled frequency or event that matched a set rule. The Vault's Callback contract are given keeper roles in the event that callbacks fail, we can utilise keepers to call these functions to process the actions and status of the vault. We can also utilise OpenZeppelin Sentinel to monitor for Events emitted by GMX to then trigger keeper (autotasks) actions. In the future, keepers may be decentralized with Chainlink Automation or Gelato Keepers.
- **Vault**: Referring only to the strategy vault itself.
- **User**: A depositor to the strategy vault.
- **Any**: Any of the above / public.

| Role  | Action | Expected Impact |
| ----- | ------ | --------------- |
| Owner | updateKeeper | Approve or revoke an address to have "keeper" role |
| Owner | updateTreasury | Update protocol's treasury address for this vault |
| Owner | updateSwapRouter | Update the external router where assets are swapped at for this vault |
| Owner | updateCallback | Update the Callback contract which handles callbacks from GMX. This function should only be called once on the post-deployment and as part of this vault's initialization
| Owner | updatefeePerSecond | Update management fee for vault |
| Owner | updateParameterLimits | Update vault's strategy debt ratio and delta parameter limits of which if crossed, the vault shoudl be rebalanced. Also updates the after deposit/withdraw "Guard Check" for the step change threshold for debt ratio step |
| Owner | updateMinSlippage | Update the minimum amount of slippage that should be passed in for adding/removing liquidity and asset swaps |
| Owner | updateMinExecutionFee | Update the minimum amount of execution fee that has to be passed in for actions that require it (adding/removing liquidity) |
| Keeper | processDeposit | Called after a successful add liquidity to GMX, from a user deposit action. Proceeds to perform after deposit health checks of the vault and mint vault shares tokens to depositor. Should be called via a Callback. |
| Keeper | processDepositCancellation | Called after add liquidity to GMX has failed -- usually due to an overly aggressive slippage requirement, after a user deposit action. Proceeds to repay borrowed assets and return the deposited assets to the user. Should be called via a Callback. |
| Keeper | processDepositFailure | Called after add liquidity to GMX has succeeded after a user deposit action, but after deposit checks of the vault's health has failed. Proceeds to withdraw the liquidity that was just added from GMX. Should be called via a Sentinel event monitored triggered autotask keeper action. |
| Keeper | processDepositFailureLiquidityWithdrawal | Called after liquidity is successfully removed from GMX via processDepositFailure(). Proceeds to repay the assets borrowed from the initial deposit, and returns the remaining assets to the depositor. Should be called via a Callback. |
| Keeper | processWithdraw | Called after a successful removal of liquidity from GMX, from a user withdraw action. Proceeds to calculate, swap -- if needed -- and repay assets for debt, and perform after withdrawal health checks of the vault, transfering assets to the withdrawer and burn vault shares tokens of withdrawer. Should be called via a Callback. |
| Keeper | processWithdrawCancellation | Called after removal of liquidity from GMX has failed -- usually due to an overly aggressive slippage requirement, after a user withdraw action. No action needed beyond resetting status of the vault to Open. Should be called via a Callback. |
| Keeper | processWithdrawFailure | Called after removal of liquidity from GMX has succeeded after a user withdraw action, but after withdrawal checks of the vault's health has failed. Proceeds to re-borrow the assets that were just repaid, and re-add assets as liquidity to GMX. Should be called via a Sentinel event monitored triggered autotask keeper action. |
| Keeper | processWithdrawFailureLiquidityAdded | Called after liquidity is successfully added from GMX via processWithdrawFailure(). Proceeds to reset the vault's status to Open. Should be called via a Callback. |
| Keeper | rebalanceAdd | Rebalance vault while borrowing more assets and adding more liquidity to GMX. Should be called via a scheduled keeper autotask. |
| Keeper | processRebalanceAdd | Called after a successful add liquidity to GMX, from a rebalanceAdd() action. Performs after rebalance add checks. Should be called via a Callback. |
| Keeper | processRebalanceAddCancellation | Called after add liquidity to GMX has failed -- usually due to an overly aggressive slippage requirement, after a rebalance add action. Proceeds to repay borrowed assets and return the deposited assets to the user. Should be called via a Callback. |
| Keeper | rebalanceRemove | Rebalance vault while reducing debt, first by removing liquidity from GMX. Should be called via a scheduled keeper autotask. |
| Keeper | processRebalanceRemove | Called after a successful removal of liquidity from GMX, from a rebalanceRemove() action. Performs repayment of assets and after rebalance remove checks. Should be called via a Callback. |
| Keeper | processRebalanceRemoveCancellation | Called after removing liquidity from GMX has failed -- usually due to an overly aggressive slippage requirement, after a rebalance remove action. Proceeds to reset vault's status to Open. Should be called via a Callback. |
| Keeper| compound | Compounds token -- typically given as a bonus reward --  by swapping the token to one of the accepted asset in the vault and adding it for more liquidity to GMX |
| Keeper | processCompound | Called after successful adding of from a compound() action. Resets vault status to Open. Should be called via a Callback. |
| Keeper | processCompoundCancellation | Called after failure of adding of liquidity from a compound() action. Resets vault status to Open. Should be called via a Callback. |
| Keeper | emergencyPause | Converts liquidity pool tokens to underlying assets and leave it it vault. Pauses vault so no asset deposits/borrows/rebalancing are allowed. |
| Owner | emergencyResume | Re-add liquidity to protocol using all assets in vault. |
| Keeper | processEmergencyResume | Set status of vault to open upon successful re-adding of liquidity from emergencyResume() |
| Owner | emergencyClose | Repays all borowed debt of vault and close vault for good. Should be called only after EmergencyPause() is called. |
| Vault | mint | Mints strategy vault share tokens |
| Vault | burn | Burns strategy vault share tokens |
| User | deposit | Deposit whitelisted asset (tokenA/tokenB/LP token) for strategy vault tokens shares |
| User | depositNative | Deposit native asset (ETH, AVAX, etc.) for strategy vault tokens shares |
| User | withdraw | Withdraw whitelisted asset (tokenA/tokenB/LP token) in exchange for strategy vault tokens shares |
| User | emergencyWithdraw | Emergency withdraw tokenA/tokenB assets in exchange for strategy vault tokens shares when vault has been shut down via EmergencyClose() |
| Any | mintFee | Mints strategy vault token shares as management fee to protocol treasury. |
| Any | store | Returns the vault's Store struct which holds numerous vault's configuration data and interaction caches |
| Any | isTokenWhitelisted | Returns whether the passed in address is a accepted token for deposits or withdrawals in this vault |
| Any | svTokenValue | Returns the vault's token value = total value of vault in USD / total supply of strategy vault tokens |
| Any | pendingFee | Returns the amount of shares to be minted as management fees to the vault  |
| Any | valueToShares | Returns the amount of shares given an equity value  |
| Any | convertToUsdValue | Returns the USD value of a given token amount |
| Any | tokenWeights | Returns the token weights of the assets in the liquidity pool of GMX |
| Any | assetValue | Returns the total value of token A & token B assets held by the vault. Assets = Debt + Equity |
| Any | debtValue | Returns the value of token A & token B debt held by the vault. Assets = Debt + Equity |
| Any | equityValue | Returns the value of token A & token B equity held by the vault. Assets = Debt + Equity |
| Any | assetAmt | Returns the total amount of token A & token B assets held by the vault |
| Any | debtAmt | Returns the total amount of token A & token B borrowed by the vault |
| Any | lpAmt | Returns the total amount of LP tokens held by the vault |
| Any | leverage | Returns the current leverage status of the vault (asset / equity)|
| Any | delta | Returns the current delta (tokenA equityValue / vault equityValue) |
| Any | debtRatio | Returns the debt ratio (tokenA and tokenB debtValue) / (total assetValue) of the vault |
| Any | additionalCapacity | Returns the amount (in USD value) that the vault can still accept as deposits |
| Any | capacity | Returns the total capacity of the vault (additionalCapacity + total equity value) |


## Strategy Vault Sequence Diagrams
High level deposit, withdraw, rebalance add, rebalance remove, compound and emergency flows.


<details>
  <summary>

  ### Strategy Vault Deposit Sequence Flow
  </summary>

  ```mermaid
  ---
  title: GMX Strategy Vault Deposit Sequence Flow
  ---
  flowchart TD
    F1(deposit) -->|addLiquidity to GMX| S1{Success?}
    S1{Success?} -->|Yes| F2(afterDepositExecution)
    S1{Success?} -->|No| F3(afterDepositCancellation)

    F2(afterDepositExecution) --> F4(processDeposit)
    F4(processDeposit) -->|afterDepositChecks| S2{Success?}

    S2{Success?} -->|Yes| DC[DepositCompleted]
    S2{Success?} -->|No| DF[DepositFailed]

    DF[DepositFailed] -->|Keeper to call| F5(processDepositFailure)
    F5(processDepositFailure) --> F6(processDepositFailureLiquidityWithdrawal)

    F3(afterDepositCancellation) --> F7(processDepositCancellation)
  ```
</details>


<details>
  <summary>

  ### Strategy Vault Withdraw Sequence Flow
  </summary>

  ```mermaid
  ---
  title: GMX Strategy Vault Withdraw Sequence Flow
  ---
  flowchart TD
    F1(deposit) -->|removeLiquidity from GMX| S1{Success?}
    S1{Success?} -->|Yes| F2(afterWithdrawExecution)
    S1{Success?} -->|No| F3(afterWithdrawCancellation)

    F2(afterWithdrawExecution) --> F4(processWithdraw)
    F4(processWithdraw) -->|afterWithdrawChecks| S2{Success?}

    S2{Success?} -->|Yes| DC[WithdrawCompleted]
    S2{Success?} -->|No| DF[WithdrawFailed]

    DF[WithdrawFailed] -->|Keeper to call| F5(processWithdrawFailure)
    F5(processWithdrawFailure) --> F6(processWithdrawFailureLiquidityWithdrawal)

    F3(afterWithdrawCancellation) --> F7(processWithdrawCancellation)
  ```
</details>

<details>
  <summary>

  ### Strategy Vault Rebalance Add Sequence Flow
  </summary>

  ```mermaid
  ---
  title: GMX Strategy Vault Rebalance Add Sequence Flow
  ---
  flowchart TD
    F1(rebalanceAdd) -->|addLiquidity to GMX| S1{Success?}
    S1{Success?} -->|Yes| F2(afterDepositExecution)
    S1{Success?} -->|No| F3(afterDepositCancellation)

    F2(afterDepositExecution) --> F4(processRebalanceAdd)
    F4(processRebalanceAdd) -->|afterRebalanceChecks| S2{Success?}

    S2{Success?} -->|Yes| DC[RebalanceSuccess]
    S2{Success?} -->|No| DF[RebalanceOpen]

    F3(afterDepositCancellation) --> F7(processRebalanceAddCancellation)
```
</details>

<details>
  <summary>

  ### Strategy Vault Rebalance Remove Sequence Flow
  </summary>

  ```mermaid
  ---
  title: GMX Strategy Vault Rebalance Remove Sequence Flow
  ---
  flowchart TD
    F1(rebalanceRemove) -->|removeLiquidity from GMX| S1{Success?}
    S1{Success?} -->|Yes| F2(afterDepositExecution)
    S1{Success?} -->|No| F3(afterDepositCancellation)

    F2(afterDepositExecution) --> F4(processRebalanceRemove)
    F4(processRebalanceRemove) -->|afterRebalanceChecks| S2{Success?}

    S2{Success?} -->|Yes| DC[RebalanceSuccess]
    S2{Success?} -->|No| DF[RebalanceOpen]

    F3(afterDepositCancellation) --> F7(processRebalanceRemoveCancellation)
  ```
</details>

<details>
  <summary>

  ### Strategy Vault Compound Sequence Flow
  </summary>

  ```mermaid
  ---
  title: GMX Strategy Vault Compound Sequence Flow
  ---
  flowchart TD
    F1(compound) -->|addLiquidity to GMX| S1{Success?}
    S1{Success?} -->|Yes| F2([afterDepositExecution])
    S1{Success?} -->|No| F3(afterDepositCancellation)

    F2(afterDepositExecution) --> F4(processCompound)
    F4(processCompound) --> CS(Compound)

    F3(afterDepositCancellation) --> F7(processCompoundCancellation)
  ```
  </details>

<details>
  <summary>

  ### Strategy Vault Emergency Sequence Flow
  </summary>

  ```mermaid
  ---
  title: GMX Strategy Vault Rebalance Emergency Flow
  ---
  flowchart TD
    F1(emergencyPause) -->|removeLiquidity from GMX| EP[EmergencyPaused]

    EP[EmergencyPaused] --> ER(emergencyResume)
    ER(emergencyResume) --> F2(afterDepositExecution)
    F2(afterDepositExecution) --> PER(processEmergencyResume) --> Open

    EP[EmergencyPaused] --> EC(emergencyClose)

    EC(emergencyClose) --> EW(emergencyWithdraw)
  ```
</details>
