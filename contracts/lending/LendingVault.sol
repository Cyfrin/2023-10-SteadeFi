// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ILendingVault } from "../interfaces/lending/ILendingVault.sol";
import { IWNT } from "../interfaces/tokens/IWNT.sol";
import { Errors } from "../utils/Errors.sol";

contract LendingVault is ERC20, ReentrancyGuard, Pausable, Ownable2Step, ILendingVault {
  using SafeERC20 for IERC20;

  /* ====================== CONSTANTS ======================== */

  uint256 public constant SAFE_MULTIPLIER = 1e18;
  uint256 public constant SECONDS_PER_YEAR = 365 days;

  /* ==================== STATE VARIABLES ==================== */

  // Vault's underlying asset
  IERC20 public asset;
  // Is asset native ETH
  bool public isNativeAsset;
  // Protocol treasury address
  address public treasury;
  // Amount borrowed from this vault
  uint256 public totalBorrows;
  // Total borrow shares in this vault
  uint256 public totalBorrowDebt;
  // The fee % applied to interest earned that goes to the protocol in 1e18
  uint256 public performanceFee;
  // Protocol earnings reserved in this vault
  uint256 public vaultReserves;
  // Last updated timestamp of this vault
  uint256 public lastUpdatedAt;
  // Max capacity of vault in asset decimals / amt
  uint256 public maxCapacity;
  // Interest rate model
  InterestRate public interestRate;
  // Max interest rate model limits
  InterestRate public maxInterestRate;

  /* ======================= MAPPINGS ======================== */

  // Mapping of borrowers to borrowers struct
  mapping(address => Borrower) public borrowers;
  // Mapping of approved keepers
  mapping(address => bool) public keepers;

  /* ======================== EVENTS ========================= */

  event Deposit(address indexed depositor, uint256 sharesAmt, uint256 depositAmt);
  event Withdraw(address indexed withdrawer, uint256 sharesAmt, uint256 withdrawAmt);
  event Borrow(address indexed borrower, uint256 borrowDebt, uint256 borrowAmt);
  event Repay(address indexed borrower, uint256 repayDebt, uint256 repayAmt);
  event PerformanceFeeUpdated(
    address indexed caller,
    uint256 previousPerformanceFee,
    uint256 newPerformanceFee
  );
  event UpdateMaxCapacity(uint256 maxCapacity);
  event EmergencyShutdown(address indexed caller);
  event EmergencyResume(address indexed caller);
  event UpdateInterestRate(
    uint256 baseRate,
    uint256 multiplier,
    uint256 jumpMultiplier,
    uint256 kink1,
    uint256 kink2
  );
  event UpdateMaxInterestRate(
    uint256 baseRate,
    uint256 multiplier,
    uint256 jumpMultiplier,
    uint256 kink1,
    uint256 kink2
  );

  /* ======================= MODIFIERS ======================= */

  /**
    * @notice Allow only approved borrower addresses
  */
  modifier onlyBorrower() {
    _onlyBorrower();
    _;
  }

  /**
    * @notice Allow only keeper addresses
  */
  modifier onlyKeeper() {
    _onlyKeeper();
    _;
  }

  /* ====================== CONSTRUCTOR ====================== */

  /**
    * @param _name  Name for this lending vault, e.g. Interest Bearing AVAX
    * @param _symbol  Symbol for this lending vault, e.g. ibAVAX-AVAXUSDC-GMX
    * @param _asset  Contract address for underlying ERC20 asset
    * @param _isNativeAsset  Whether vault asset is native or not
    * @param _performanceFee  Performance fee in 1e18
    * @param _maxCapacity Max capacity of lending vault in asset decimals
    * @param _treasury  Contract address for protocol treasury
    * @param _interestRate  InterestRate struct initial
    * @param _maxInterestRate  InterestRate struct for max interest rates
  */
  constructor(
    string memory _name,
    string memory _symbol,
    IERC20 _asset,
    bool _isNativeAsset,
    uint256 _performanceFee,
    uint256 _maxCapacity,
    address _treasury,
    InterestRate memory _interestRate,
    InterestRate memory _maxInterestRate
  ) ERC20(_name, _symbol) Ownable(msg.sender) {
    if (address(_asset) == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (_treasury == address(0)) revert Errors.ZeroAddressNotAllowed();
    if (ERC20(address(_asset)).decimals() > 18) revert Errors.TokenDecimalsMustBeLessThan18();

    asset = _asset;
    isNativeAsset = _isNativeAsset;
    performanceFee = _performanceFee;
    maxCapacity = _maxCapacity;
    treasury = _treasury;

    interestRate.baseRate = _interestRate.baseRate;
    interestRate.multiplier = _interestRate.multiplier;
    interestRate.jumpMultiplier = _interestRate.jumpMultiplier;
    interestRate.kink1 = _interestRate.kink1;
    interestRate.kink2 = _interestRate.kink2;

    maxInterestRate.baseRate = _maxInterestRate.baseRate;
    maxInterestRate.multiplier = _maxInterestRate.multiplier;
    maxInterestRate.jumpMultiplier = _maxInterestRate.jumpMultiplier;
    maxInterestRate.kink1 = _maxInterestRate.kink1;
    maxInterestRate.kink2 = _maxInterestRate.kink2;
  }

  /* ===================== VIEW FUNCTIONS ==================== */

  /**
    * @notice Returns the total value of the lending vault, i.e totalBorrows + interest + totalAvailableAsset
    * @return totalAsset   Total value of lending vault in token decimals
  */
  function totalAsset() public view returns (uint256) {
    return totalBorrows + _pendingInterest(0) + totalAvailableAsset();
  }

  /**
    * @notice Returns the available balance of asset in the vault that is borrowable
    * @return totalAvailableAsset   Balance of asset in the vault in token decimals
  */
  function totalAvailableAsset() public view returns (uint256) {
    return asset.balanceOf(address(this));
  }

  /**
    * @notice Returns the the borrow utilization rate of the vault
    * @return utilizationRate   Ratio of borrows to total liquidity in 1e18
  */
  function utilizationRate() public view returns (uint256){
    uint256 totalAsset_ = totalAsset();

    return (totalAsset_ == 0) ? 0 : totalBorrows * SAFE_MULTIPLIER / totalAsset_;
  }

  /**
    * @notice Returns the exchange rate for lvToken to asset
    * @return lvTokenValue   Ratio of lvToken to underlying asset in token decimals
  */
  function lvTokenValue() public view returns (uint256) {
    uint256 totalAsset_ = totalAsset();
    uint256 totalSupply_ = totalSupply();

    if (totalAsset_ == 0 || totalSupply_ == 0) {
      return 1 * (10 ** ERC20(address(asset)).decimals());
    } else {
      return totalAsset_ * SAFE_MULTIPLIER / totalSupply_;
    }
  }

  /**
    * @notice Returns the current borrow APR
    * @return borrowAPR   Current borrow rate in 1e18
  */
  function borrowAPR() public view returns (uint256) {
    return _calculateInterestRate(totalBorrows, totalAvailableAsset());
  }

  /**
    * @notice Returns the current lending APR; borrowAPR * utilization * (1 - performanceFee)
    * @return lendingAPR   Current lending rate in 1e18
  */
  function lendingAPR() public view returns (uint256) {
    uint256 borrowAPR_ = borrowAPR();
    uint256 utilizationRate_ = utilizationRate();

    if (borrowAPR_ == 0 || utilizationRate_ == 0) {
      return 0;
    } else {
      return borrowAPR_ * utilizationRate_
                         / SAFE_MULTIPLIER
                         * ((1 * SAFE_MULTIPLIER) - performanceFee)
                         / SAFE_MULTIPLIER;
    }
  }

  /**
    * @notice Returns a borrower's maximum total repay amount taking into account ongoing interest
    * @param borrower   Borrower's address
    * @return maxRepay   Borrower's total repay amount of assets in assets decimals
  */
  function maxRepay(address borrower) public view returns (uint256) {
    if (totalBorrows == 0) {
      return 0;
    } else {
      return borrowers[borrower].debt * (totalBorrows + _pendingInterest(0)) / totalBorrowDebt;
    }
  }

  /* ================== MUTATIVE FUNCTIONS =================== */

  /**
    * @notice Deposits native asset into lending vault and mint shares to user
    * @param assetAmt Amount of asset tokens to deposit in token decimals
    * @param minSharesAmt Minimum amount of lvTokens tokens to receive on deposit
  */
  function depositNative(uint256 assetAmt, uint256 minSharesAmt) payable public nonReentrant whenNotPaused {
    if (msg.value == 0) revert Errors.EmptyDepositAmount();
    if (assetAmt != msg.value) revert Errors.InvalidNativeDepositAmountValue();
    if (assetAmt + totalAsset() > maxCapacity) revert Errors.InsufficientCapacity();
    if (assetAmt == 0) revert Errors.InsufficientDepositAmount();

    IWNT(address(asset)).deposit{ value: msg.value }();

    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(assetAmt);

    uint256 _sharesAmount = _mintShares(assetAmt);

    if (_sharesAmount < minSharesAmt) revert Errors.InsufficientSharesMinted();

    emit Deposit(msg.sender, _sharesAmount, assetAmt);
  }

  /**
    * @notice Deposits asset into lending vault and mint shares to user
    * @param assetAmt Amount of asset tokens to deposit in token decimals
    * @param minSharesAmt Minimum amount of lvTokens tokens to receive on deposit
  */
  function deposit(uint256 assetAmt, uint256 minSharesAmt) public nonReentrant whenNotPaused {
    if (assetAmt + totalAsset() > maxCapacity) revert Errors.InsufficientCapacity();
    if (assetAmt == 0) revert Errors.InsufficientDepositAmount();

    asset.safeTransferFrom(msg.sender, address(this), assetAmt);

    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(assetAmt);

    uint256 _sharesAmount = _mintShares(assetAmt);

    if (_sharesAmount < minSharesAmt) revert Errors.InsufficientSharesMinted();

    emit Deposit(msg.sender, _sharesAmount, assetAmt);
  }

  /**
    * @notice Withdraws asset from lending vault, burns lvToken from user
    * @param sharesAmt Amount of lvTokens to burn in 1e18
    * @param minAssetAmt Minimum amount of asset tokens to receive on withdrawal
  */
  function withdraw(uint256 sharesAmt, uint256 minAssetAmt) public nonReentrant whenNotPaused {
    if (sharesAmt == 0) revert Errors.InsufficientWithdrawAmount();
    if (sharesAmt > balanceOf(msg.sender)) revert Errors.InsufficientWithdrawBalance();

    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(0);

    uint256 _assetAmt = _burnShares(sharesAmt);

    if (_assetAmt > totalAvailableAsset()) revert Errors.InsufficientAssetsBalance();
    if (_assetAmt < minAssetAmt) revert Errors.InsufficientAssetsReceived();

    if (isNativeAsset) {
      IWNT(address(asset)).withdraw(_assetAmt);
      (bool success, ) = msg.sender.call{value: _assetAmt}("");
      require(success, "Transfer failed.");
    } else {
      asset.safeTransfer(msg.sender, _assetAmt);
    }

    emit Withdraw(msg.sender, sharesAmt, _assetAmt);
  }

  /**
    * @notice Borrow asset from lending vault, adding debt
    * @param borrowAmt Amount of tokens to borrow in token decimals
  */
  function borrow(uint256 borrowAmt) external nonReentrant whenNotPaused onlyBorrower {
    if (borrowAmt == 0) revert Errors.InsufficientBorrowAmount();
    if (borrowAmt > totalAvailableAsset()) revert Errors.InsufficientLendingLiquidity();

    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(0);

    // Calculate debt amount
    uint256 _debt = totalBorrows == 0 ? borrowAmt : borrowAmt * totalBorrowDebt / totalBorrows;

    // Update vault state
    totalBorrows = totalBorrows + borrowAmt;
    totalBorrowDebt = totalBorrowDebt + _debt;

    // Update borrower state
    Borrower storage borrower = borrowers[msg.sender];
    borrower.debt = borrower.debt + _debt;
    borrower.lastUpdatedAt = block.timestamp;

    // Transfer borrowed token from vault to manager
    asset.safeTransfer(msg.sender, borrowAmt);

    emit Borrow(msg.sender, _debt, borrowAmt);
  }

  /**
    * @notice Repay asset to lending vault, reducing debt
    * @param repayAmt Amount of debt to repay in token decimals
  */
  function repay(uint256 repayAmt) external nonReentrant {
    if (repayAmt == 0) revert Errors.InsufficientRepayAmount();
    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(0);

    uint256 maxRepay_ = maxRepay(msg.sender);
    if (maxRepay_ > 0) {
      if (repayAmt > maxRepay_) {
        repayAmt = maxRepay_;
      }

      // Calculate debt to reduce based on repay amount
      uint256 _debt = repayAmt * borrowers[msg.sender].debt / maxRepay_;

      // Update vault state
      totalBorrows = totalBorrows - repayAmt;
      totalBorrowDebt = totalBorrowDebt - _debt;

      // Update borrower state
      borrowers[msg.sender].debt = borrowers[msg.sender].debt - _debt;
      borrowers[msg.sender].lastUpdatedAt = block.timestamp;

      // Transfer repay tokens to the vault
      asset.safeTransferFrom(msg.sender, address(this), repayAmt);

      emit Repay(msg.sender, _debt, repayAmt);
    }
  }

  /**
  * @notice Withdraw protocol fees from reserves to treasury
  * @param assetAmt  Amount to withdraw in token decimals
  */
  function withdrawReserve(uint256 assetAmt) external nonReentrant onlyKeeper {
    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(0);

    if (assetAmt > vaultReserves) assetAmt = vaultReserves;

    unchecked {
      vaultReserves = vaultReserves - assetAmt;
    }

    asset.safeTransfer(treasury, assetAmt);
  }

  /* ================== INTERNAL FUNCTIONS =================== */

  /**
    * @notice Allow only approved borrower addresses
  */
  function _onlyBorrower() internal view {
    if (!borrowers[msg.sender].approved) revert Errors.OnlyBorrowerAllowed();
  }

  /**
    * @notice Allow only keeper addresses
  */
  function _onlyKeeper() internal view {
    if (!keepers[msg.sender]) revert Errors.OnlyKeeperAllowed();
  }

  /**
    * @notice Calculate amount of lvTokens owed to depositor and mints them
    * @param assetAmt  Amount of asset to deposit in token decimals
    * @return shares  Amount of lvTokens minted in 1e18
  */
  function _mintShares(uint256 assetAmt) internal returns (uint256) {
    uint256 _shares;

    if (totalSupply() == 0) {
      _shares = assetAmt * _to18ConversionFactor();
    } else {
      _shares = assetAmt * totalSupply() / (totalAsset() - assetAmt);
    }

    // Mint lvToken to user equal to liquidity share amount
    _mint(msg.sender, _shares);

    return _shares;
  }

  /**
    * @notice Calculate amount of asset owed to depositor based on lvTokens burned
    * @param sharesAmt Amount of shares to burn in 1e18
    * @return withdrawAmount  Amount of assets withdrawn based on lvTokens burned in token decimals
  */
  function _burnShares(uint256 sharesAmt) internal returns (uint256) {
    // Calculate amount of assets to withdraw based on shares to burn
    uint256 totalSupply_ = totalSupply();
    uint256 _withdrawAmount = totalSupply_ == 0 ? 0 : sharesAmt * totalAsset() / totalSupply_;

    // Burn user's lvTokens
    _burn(msg.sender, sharesAmt);

    return _withdrawAmount;
  }

  /**
    * @notice Interest accrual function that calculates accumulated interest from lastUpdatedTimestamp and add to totalBorrows
    * @param assetAmt Additonal amount of assets being deposited in token decimals
  */
  function _updateVaultWithInterestsAndTimestamp(uint256 assetAmt) internal {
    uint256 _interest = _pendingInterest(assetAmt);
    uint256 _toReserve = _interest * performanceFee / SAFE_MULTIPLIER;

    vaultReserves = vaultReserves + _toReserve;
    totalBorrows = totalBorrows + _interest;
    lastUpdatedAt = block.timestamp;
  }

  /**
    * @notice Returns the pending interest that will be accrued to the reserves in the next call
    * @param assetAmt Newly deposited assets to be subtracted off total available liquidity in token decimals
    * @return interest  Amount of interest owned in token decimals
  */
  function _pendingInterest(uint256 assetAmt) internal view returns (uint256) {
    if (totalBorrows == 0) return 0;

    uint256 totalAvailableAsset_ = totalAvailableAsset();
    uint256 _timePassed = block.timestamp - lastUpdatedAt;
    uint256 _floating = totalAvailableAsset_ == 0 ? 0 : totalAvailableAsset_ - assetAmt;
    uint256 _ratePerSec = _calculateInterestRate(totalBorrows, _floating) / SECONDS_PER_YEAR;

    // First division is due to _ratePerSec being in 1e18
    // Second division is due to _ratePerSec being in 1e18
    return _ratePerSec * totalBorrows * _timePassed / SAFE_MULTIPLIER;
  }

  /**
    * @notice Conversion factor for tokens with less than 1e18 to return in 1e18
    * @return conversionFactor  Amount of decimals for conversion to 1e18
  */
  function _to18ConversionFactor() internal view returns (uint256) {
    unchecked {
      if (ERC20(address(asset)).decimals() == 18) return 1;

      return 10**(18 - ERC20(address(asset)).decimals());
    }
  }

  /**
    * @notice Return the interest rate based on the utilization rate
    * @param debt Total borrowed amount
    * @param floating Total available liquidity
    * @return rate Current interest rate in 1e18
  */
  function _calculateInterestRate(uint256 debt, uint256 floating) internal view returns (uint256) {
    if (debt == 0 && floating == 0) return 0;

    uint256 _total = debt + floating;
    uint256 _utilization = debt * SAFE_MULTIPLIER / _total;

    // If _utilization above kink2, return a higher interest rate
    // (base + rate + excess _utilization above kink 2 * jumpMultiplier)
    if (_utilization > interestRate.kink2) {
      return interestRate.baseRate + (interestRate.kink1 * interestRate.multiplier / SAFE_MULTIPLIER)
                      + ((_utilization - interestRate.kink2) * interestRate.jumpMultiplier / SAFE_MULTIPLIER);
    }

    // If _utilization between kink1 and kink2, rates are flat
    if (interestRate.kink1 < _utilization && _utilization <= interestRate.kink2) {
      return interestRate.baseRate + (interestRate.kink1 * interestRate.multiplier / SAFE_MULTIPLIER);
    }

    // If _utilization below kink1, calculate borrow rate for slope up to kink 1
    return interestRate.baseRate + (_utilization * interestRate.multiplier / SAFE_MULTIPLIER);
  }

  /* ================= RESTRICTED FUNCTIONS ================== */

  /**
    * @notice Updates lending vault interest rate model variables, callable only by keeper
    * @param newInterestRate InterestRate struct
  */
  function updateInterestRate(InterestRate memory newInterestRate) public onlyKeeper {
    if (
      newInterestRate.baseRate > maxInterestRate.baseRate ||
      newInterestRate.multiplier > maxInterestRate.multiplier ||
      newInterestRate.jumpMultiplier > maxInterestRate.jumpMultiplier ||
      newInterestRate.kink1 > maxInterestRate.kink1 ||
      newInterestRate.kink2 > maxInterestRate.kink2
    ) revert Errors.InterestRateModelExceeded();

    interestRate.baseRate = newInterestRate.baseRate;
    interestRate.multiplier = newInterestRate.multiplier;
    interestRate.jumpMultiplier = newInterestRate.jumpMultiplier;
    interestRate.kink1 = newInterestRate.kink1;
    interestRate.kink2 = newInterestRate.kink2;

    emit UpdateInterestRate(
      interestRate.baseRate,
      interestRate.multiplier,
      interestRate.jumpMultiplier,
      interestRate.kink1,
      interestRate.kink2
    );
  }

  /**
    * @notice Update perf fee
    * @param newPerformanceFee  Fee percentage in 1e18
  */
  function updatePerformanceFee(uint256 newPerformanceFee) external onlyOwner {
    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(0);

    performanceFee = newPerformanceFee;

    emit PerformanceFeeUpdated(msg.sender, performanceFee, newPerformanceFee);
  }

  /**
    * @notice Approve address to borrow from this vault
    * @param borrower  Borrower address
  */
  function approveBorrower(address borrower) external onlyOwner {
    if (borrowers[borrower].approved) revert Errors.BorrowerAlreadyApproved();

    borrowers[borrower].approved = true;
  }

  /**
    * @notice Revoke address to borrow from this vault
    * @param borrower  Borrower address
  */
  function revokeBorrower(address borrower) external onlyOwner {
    if (!borrowers[borrower].approved) revert Errors.BorrowerAlreadyRevoked();

    borrowers[borrower].approved = false;
  }

  /**
    * @notice Approve or revoke address to be a keeper for this vault
    * @param keeper Keeper address
    * @param approval Boolean to approve keeper or not
  */
  function updateKeeper(address keeper, bool approval) external onlyOwner {
    if (keeper == address(0)) revert Errors.ZeroAddressNotAllowed();

    keepers[keeper] = approval;
  }

  /**
    * @notice Emergency repay of assets to lending vault to clear bad debt
    * @param repayAmt Amount of debt to repay in token decimals
  */
  function emergencyRepay(uint256 repayAmt, address defaulter) external nonReentrant onlyKeeper {
    if (repayAmt == 0) revert Errors.InsufficientRepayAmount();

    // Update vault with accrued interest and latest timestamp
    _updateVaultWithInterestsAndTimestamp(0);

    uint256 maxRepay_ = maxRepay(defaulter);

    if (maxRepay_ > 0) {
      if (repayAmt > maxRepay_) {
        repayAmt = maxRepay_;
      }

      // Calculate debt to reduce based on repay amount
      uint256 _debt = repayAmt * borrowers[defaulter].debt / maxRepay_;

      // Update vault state
      totalBorrows = totalBorrows - repayAmt;
      totalBorrowDebt = totalBorrowDebt - _debt;

      // Update borrower state
      borrowers[defaulter].debt = borrowers[defaulter].debt - _debt;
      borrowers[defaulter].lastUpdatedAt = block.timestamp;

      // Transfer repay tokens to the vault
      asset.safeTransferFrom(msg.sender, address(this), repayAmt);

      emit Repay(defaulter, _debt, repayAmt);
    }
  }

  /**
    * @notice Emergency pause of lending vault that pauses all deposits, borrows and normal withdrawals
  */
  function emergencyShutdown() external whenNotPaused onlyKeeper {
    _pause();

    emit EmergencyShutdown(msg.sender);
  }

  /**
    * @notice Emergency resume of lending vault that pauses all deposits, borrows and normal withdrawals
  */
  function emergencyResume() external whenPaused onlyOwner {
    _unpause();

    emit EmergencyResume(msg.sender);
  }

  /**
    * @notice Update max capacity value
    * @param newMaxCapacity Capacity value in token decimals (amount)
  */
  function updateMaxCapacity(uint256 newMaxCapacity) external onlyOwner {
    maxCapacity = newMaxCapacity;

    emit UpdateMaxCapacity(newMaxCapacity);
  }

  /**
    * @notice Updates maximum allowed lending vault interest rate model variables
    * @param newMaxInterestRate InterestRate struct
  */
  function updateMaxInterestRate(InterestRate memory newMaxInterestRate) public onlyOwner {
    maxInterestRate.baseRate = newMaxInterestRate.baseRate;
    maxInterestRate.multiplier = newMaxInterestRate.multiplier;
    maxInterestRate.jumpMultiplier = newMaxInterestRate.jumpMultiplier;
    maxInterestRate.kink1 = newMaxInterestRate.kink1;
    maxInterestRate.kink2 = newMaxInterestRate.kink2;

    emit UpdateMaxInterestRate(
      maxInterestRate.baseRate,
      maxInterestRate.multiplier,
      maxInterestRate.jumpMultiplier,
      maxInterestRate.kink1,
      maxInterestRate.kink2
    );
  }

  /**
    * @notice Update treasury address
    * @param newTreasury Treasury address
  */
  function updateTreasury(address newTreasury) external onlyOwner {
    if (newTreasury == address(0)) revert Errors.ZeroAddressNotAllowed();

    treasury = newTreasury;
  }

  /* ================== FALLBACK FUNCTIONS =================== */

  /**
    * @notice Fallback function to receive native token sent to this contract,
    * needed for receiving native token to contract when unwrapped
  */
  receive() external payable {
    if (!isNativeAsset) revert Errors.OnlyNonNativeDepositToken();
  }
}
