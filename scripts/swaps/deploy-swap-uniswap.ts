import hre from 'hardhat';
import { ethers } from "hardhat";
import { CONSTANTS } from '../../constants';

async function main() {
  const [owner, addr1] = await ethers.getSigners();

  console.log("===============================");
  console.log("Deployer address:", owner.address);

  /* Deploy Swap */
  const uniswap = await ethers.deployContract(
    'UniswapSwap',
    [
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.UNI_SWAP_ROUTER,
      CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.CHAINLINK_ORACLE,
    ],
    {}
  );

  await uniswap.waitForDeployment();

  console.log("UniswapSwap deployed to:", uniswap.target);

  // const uniswap = await ethers.getContractAt('UniswapSwap', '0x0291C00c3088f301Cef8cd893f1C64902e08A96F');

  console.log(' ');
  console.log('Verifying UniswapSwap...');

  try {
    await hre.run('verify:verify', {
      address: uniswap.target,
      contract: 'contracts/swaps/UniswapSwap.sol:UniswapSwap',
      constructorArguments: [
        CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.UNI_SWAP_ROUTER,
        CONSTANTS.CHAIN_ID[42161].CONTRACT_ADDRESSES.CHAINLINK_ORACLE,
      ]
    })
  } catch (error) {
    console.log(error)
  }

  // Note: check https://info.uniswap.org/#/ for fee tiers of swap pools
  // Choose the ones with thie highest TVL as this results in the lowest swap slippage
  // 500 = 0.05%, 3000 = 0.3%

  console.log('Update fee tier for WETH <> USDC swap pool');
  await uniswap.connect(owner).updateFee(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
    '500' // 0.05%
  );
  await uniswap.connect(owner).updateFee(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
    '500' // 0.05%
  );

  console.log('Update fee tier for WBTC <> USDC swap pool');
  await uniswap.connect(owner).updateFee(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WBTC,
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
    '3000' // 0.3%
  );
  await uniswap.connect(owner).updateFee(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WBTC,
    '3000' // 0.3%
  );

  // console.log('Approve owner USDC allowance');
  // const USDCToken = await ethers.getContractAt(
  //   'ERC20',
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC
  // );
  // await USDCToken.connect(owner).approve(
  //   uniswap.target,
  //   ethers.parseUnits('50', 6)
  // );

  // console.log('Approve owner WETH allowance');
  // const WETHToken = await ethers.getContractAt(
  //   'ERC20',
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH
  // );
  // await WETHToken.connect(owner).approve(
  //   uniswap.target,
  //   ethers.parseUnits('0.1', 18)
  // );

  // console.log('Approve owner ARB allowance');
  // const ARBToken = await ethers.getContractAt(
  //   'ERC20',
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB
  // );
  // await ARBToken.connect(owner).approve(
  //   uniswap.target,
  //   ethers.parseUnits('10', 18)
  // );

  console.log("===============================");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
