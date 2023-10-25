// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import { console, console2 } from "forge-std/Test.sol";
import { TestUtils } from "../../helpers/TestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GMXMockVaultSetup } from "./GMXMockVaultSetup.t.sol";
import { GMXTypes } from "../../../contracts/strategy/gmx/GMXTypes.sol";
import { GMXTestHelper } from "./GMXTestHelper.sol";

import { IDeposit } from "../../../contracts/interfaces/protocols/gmx/IDeposit.sol";
import { IEvent } from "../../../contracts/interfaces/protocols/gmx/IEvent.sol";

contract GMXReaderTest is GMXMockVaultSetup, GMXTestHelper, TestUtils {
  function test_svTokenValue() external {
    vm.startPrank(user1);
    // if total supply == 0, svTokenValue should be 1e18
    assertTrue(vault.svTokenValue() == 1e18, "svTokenValue should be 0");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    assertTrue(roughlyEqual(vault.svTokenValue(), 1e18, 1e15), "svTokenValue should be 1e18");

    deal(address(WETHUSDCpair), address(vault), 1e14);
    assertGt(vault.svTokenValue(), 1e18, "svTokenValue should be > 1e18");
  }

  function test_pendingFee() external {
    vm.startPrank(user1);
    // if total supply == 0, pendingFee should be 0
    assertTrue(vault.pendingFee() == 0, "pendingFee should be 0");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    skip(1 days);

    assertTrue(vault.pendingFee() > 0, "pendingFee should be > 0");
  }

  function test_valueToShares() external {
    vm.startPrank(user1);
    // if total supply == 0, valueToShares should be value
    assertTrue(vault.valueToShares(1e18, 0) == 1e18, "valueToShares should be 1e18");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    assertTrue(roughlyEqual(vault.valueToShares(1e18, vault.equityValue()), 1e18, 1e15), "valueToShares should be 1e18");

    deal(address(WETHUSDCpair), address(vault), 1e14);
    assertLt(vault.valueToShares(1e18, vault.equityValue()), 1e18, "valueToShares should be < 1e18");
  }

  function test_convertToUsdValue() external {
    vm.startPrank(user1);
    assertTrue(vault.convertToUsdValue(address(USDC), 1e6) == 1e18, "USDC value should be 1e18");

    assertTrue(vault.convertToUsdValue(address(WETH), 1e18) == 1600e18, "WETH should be 1600e18");
  }

  function test_tokenWeights() external {
    vm.startPrank(user1);
    (uint256 tokenWeightA, uint256 tokenWeightB) = vault.tokenWeights();
    assertEq(tokenWeightA, 0.5e18, "tokenWeightA should be 50%");
    assertEq(tokenWeightB, 0.5e18, "tokenWeightB should be 50%");
  }

  function test_assetValue() external {
    vm.startPrank(user1);

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    assertTrue(roughlyEqual(vault.assetValue(), 4800e18, 10e18), "Asset value should be roughly $4800");
  }

  function test_debtValue() external {
    vm.startPrank(user1);

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    (uint256 a, uint256 b) = vault.debtValue();

    assertEq(a, 0, "WETH debt should be 0");
    assertTrue(roughlyEqual(b, 3200e18, 1e18), "USDC debt should be $3200");
  }

  function test_equityValue() external {
    vm.startPrank(user1);

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    assertTrue(roughlyEqual(vault.equityValue(), 1600e18, 10e18), "Equity value should be roughly $4800");
  }

  function test_assetAmt() external {
    vm.startPrank(user1);

    (uint256 a, uint256 b) = vault.assetAmt();

    assertEq(a, 0, "WETH asset should be 0");
    assertEq(b, 0, "USDC asset should be 0");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );
    (a, b) = vault.assetAmt();

    assertTrue(roughlyEqual(a, 1.5e18, 1e17), "WETH asset wrong");
    assertTrue(roughlyEqual(b, 2400e6, 10e6), "USDC asset wrong");
  }

  function test_debtAmt() external {
    vm.startPrank(user1);

    (uint256 a, uint256 b) = vault.debtAmt();

    assertEq(a, 0, "WETH debt should be 0");
    assertEq(b, 0, "USDC debt should be 0");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );
    (a, b) = vault.debtAmt();

    assertEq(a, 0, "WETH debt should be 0");
    assertTrue(roughlyEqual(b, 3200e6, 10e6), "USDC debt wrong");
  }

  function test_lpAmt() external {
    vm.startPrank(user1);

    assertEq(vault.lpAmt(), 0, "lpAmt should be 0");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    assertTrue(vault.lpAmt() > 0, "lpAmt should be > 0");
  }

  function test_leverageAndDebtRatio() external {
    vm.startPrank(user1);

    assertEq(vault.leverage(), 0, "leverage should be 0");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    assertTrue(roughlyEqual(vault.leverage(), 3e18, 1e17), "leverage should be 3");
    assertTrue(roughlyEqual(vault.debtRatio(), 0.67e18, 1e17), "debtRatio should be 0.67");
  }

  function test_additionalCapacity() external {
    uint256 initialCapacity = vault.additionalCapacity();
    assertEq(initialCapacity, 49999.5e18, "additionalCapacity incorrect");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    uint256 capacityAfterDeposit = vault.additionalCapacity();
    assertLt(capacityAfterDeposit, initialCapacity, "additionalCapacity incorrect");
  }

  function test_capacity() external {
    vm.startPrank(user1);

    assertEq(vault.capacity(), vault.additionalCapacity(), "capacity incorrect");

    _createAndExecuteDeposit(
      address(WETH),
      address(USDC),
      address(WETH),
      1e18,
      0,
      SLIPPAGE,
      EXECUTION_FEE
    );

    assertLt(vault.capacity(), vault.additionalCapacity() + 1600e18, "capacity incorrect");
  }
}
