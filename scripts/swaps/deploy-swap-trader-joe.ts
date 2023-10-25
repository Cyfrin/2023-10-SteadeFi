import hre from 'hardhat';
import { ethers } from "hardhat";
import { CONSTANTS } from '../../constants';

async function main() {
  const [owner, addr1] = await ethers.getSigners();

  console.log("===============================");
  console.log("Deployer address:", owner.address);

  /* Deploy Swap */
  const traderjoe = await ethers.deployContract(
    'TraderJoeSwap',
    [
      CONSTANTS.CHAIN_ID[43114].CONTRACT_ADDRESSES.TJ_LB_ROUTER_21,
      CONSTANTS.CHAIN_ID[43114].CONTRACT_ADDRESSES.CHAINLINK_ORACLE,
    ],
    {}
  );

  await traderjoe.waitForDeployment();

  console.log("TraderJoeSwap deployed to:", traderjoe.target);

  console.log(' ');
  console.log('Verifying TraderJoeSwap...');

  try {
    await hre.run('verify:verify', {
      address: traderjoe.target,
      contract: 'contracts/swaps/TraderJoeSwap.sol:TraderJoeSwap',
      constructorArguments: [
        CONSTANTS.CHAIN_ID[43114].CONTRACT_ADDRESSES.TJ_LB_ROUTER_21,
        CONSTANTS.CHAIN_ID[43114].CONTRACT_ADDRESSES.CHAINLINK_ORACLE,
      ]
    })
  } catch (error) {
    console.log(error)
  }

  // const traderjoe = await ethers.getContractAt('TraderJoeSwap', '0x46E70D76eDD8736b324D40343Df27F969e0f476F');

  // Note: check https://traderjoexyz.com/avalanche/pool for fee tiers of swap pools
  // Choose the ones with thie highest TVL as this results in the lowest swap slippage
  // 15 = 0.15%, 20 = 0.2%, 10 = 0.1%, 2 = 0.02%

  console.log('Update fee tier for WAVAX <> USDC swap pool');
  await traderjoe.connect(owner).updatePairBinStep(
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.WAVAX,
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.USDC,
    '20' // 0.2%
  );
  await traderjoe.connect(owner).updatePairBinStep(
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.USDC,
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.WAVAX,
    '20' // 0.2%
  );

  console.log('Update fee tier for WETHe <> USDC swap pool');
  await traderjoe.connect(owner).updatePairBinStep(
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.WETHe,
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.USDC,
    '15' // 0.15%
  );
  await traderjoe.connect(owner).updatePairBinStep(
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.USDC,
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.WETHe,
    '15' // 0.15%
  );

  console.log('Update fee tier for BTCb <> USDC swap pool');
  await traderjoe.connect(owner).updatePairBinStep(
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.BTCb,
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.USDC,
    '10' // 0.1%
  );
  await traderjoe.connect(owner).updatePairBinStep(
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.USDC,
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.BTCb,
    '10' // 0.1%
  );

  console.log('Approve owner USDC allowance');
  const USDCToken = await ethers.getContractAt(
    'ERC20',
    CONSTANTS.CHAIN_ID[43114].TOKEN_ADDRESSES.USDC
  );
  await USDCToken.connect(owner).approve(
    traderjoe.target,
    ethers.parseUnits('50', 6)
  );

  console.log("===============================");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
