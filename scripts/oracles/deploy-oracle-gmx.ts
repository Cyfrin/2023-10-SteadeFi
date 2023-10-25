import hre from 'hardhat';
import { ethers } from "hardhat";
import { CONSTANTS } from '../../constants';

async function main() {
  const [owner, addr1] = await ethers.getSigners();

  console.log("===============================");
  console.log("Deployer address:", owner.address);

  /* Deploy Oracle */
  const gmxOracle = await ethers.deployContract(
    'GMXOracle',
    [
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_DATA_STORE,
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_READER,
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.CHAINLINK_ORACLE,
    ],
    {}
  );

  await gmxOracle.waitForDeployment();

  console.log("GMXOracle deployed to:", gmxOracle.target);

  console.log(' ');
  console.log('Verifying GMXOracle...');

  try {
    await hre.run('verify:verify', {
      address: gmxOracle.target,
      contract: 'contracts/oracles/GMXOracle.sol:GMXOracle',
      constructorArguments: [
        CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_DATA_STORE,
        CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.GMX_READER,
        CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.CHAINLINK_ORACLE,
      ]
    })
  } catch (error) {
    console.log(error)
  }

  console.log("===============================");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
