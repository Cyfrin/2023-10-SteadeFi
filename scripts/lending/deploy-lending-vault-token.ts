import hre from 'hardhat';
import { ethers } from "hardhat";
import { CONSTANTS } from '../../constants';

async function main() {
  const [owner, addr1] = await ethers.getSigners();

  console.log("===============================");
  console.log("Deployer address:", owner.address);

  const DEPLOYING = true // deploying or attaching to deployed contract?

  let lendingVault;

  if (DEPLOYING) {
    const name = 'ARB Lend ARB-USDC GMX'
    const symbol = 'cARB-USDC-GMX'
    const newAsset = CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB
    const newIsNativeAsset = false
    const newPerformanceFee = ethers.parseUnits('0.2', 18)
    const newMaxCapacity = ethers.parseUnits('20', 18)
    const newTreasury = CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.TREASURY
    const newInterestRate = {
      baseRate: ethers.parseUnits('0', 18),
      multiplier: ethers.parseUnits('0.125', 18),
      jumpMultiplier: ethers.parseUnits('2.5', 18),
      kink1: ethers.parseUnits('0.8', 18),
      kink2: ethers.parseUnits('0.9', 18),
    }
    const maxNewInterestRate = {
      baseRate: ethers.parseUnits('0', 18),
      multiplier: ethers.parseUnits('10000', 18), // max 1000% APR & 90% max profit share
      jumpMultiplier: ethers.parseUnits('18', 18), // max 1000% APR & 90% max profit share
      kink1: ethers.parseUnits('0.0001', 18), // stable interest rate from 0.0001%...
      kink2: ethers.parseUnits('0.5', 18), // ...to 50% utilization rate
    }

    const constructorArguments = [
      name,
      symbol,
      newAsset,
      newIsNativeAsset,
      newPerformanceFee,
      newMaxCapacity,
      newTreasury,
      newInterestRate,
      maxNewInterestRate,
    ]

    /* Deploy Lending Vault  */
    lendingVault = await ethers.deployContract('LendingVault', constructorArguments, {});
    await lendingVault.waitForDeployment();
    console.log("LendingVault deployed to:", lendingVault.target);
    try {
      await hre.run('verify:verify', {
        address: lendingVault.target,
        contract: 'contracts/lending/LendingVault.sol:LendingVault',
        constructorArguments: constructorArguments
      })
    } catch (error) {
      console.log(error)
    }
  } else {
    lendingVault = await ethers.getContractAt(
      'LendingVault',
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.LENDING_ETH_ETHUSDC_GMX
    );
  }

  console.log('======================');
  console.log('Post deployment action');
  console.log('======================');

  console.log('Approve Relayer address for keeper');
  await lendingVault.connect(owner).updateKeeper(
    CONSTANTS.CHAIN_ID[42161].KEEPER_ADDRESSES.DEFENDER_RELAYER,
    true
  );

  console.log('Approve owner ARB allowance for lending vault');
  const depositToken = await ethers.getContractAt(
    'ERC20',
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB
  );
  await depositToken.connect(owner).approve(
    lendingVault.target,
    ethers.parseUnits('20', 18)
  );

  console.log('Deposit 0.0025 ARB to Lending Vault');
  await lendingVault.connect(owner).deposit(
    ethers.parseUnits('2', 18),
    '0',
  );

  console.log("===============================");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
