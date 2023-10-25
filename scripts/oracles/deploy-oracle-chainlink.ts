import hre from 'hardhat';
import { ethers } from "hardhat";
import { CONSTANTS } from '../../constants';

async function main() {
  const [owner, addr1] = await ethers.getSigners();

  console.log("===============================");
  console.log("Deployer address:", owner.address);

  /* Deploy Oracle */

  // =========================================
  // For Arbitrum: Use ChainlinkARBOracle.sol which requires passing in the address for ARB Sequencer
  // =========================================
  const chainklinkOracle = await ethers.deployContract(
    'ChainlinkARBOracle',
    [CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.ARB_SEQUENCER],
    {}
  );

  await chainklinkOracle.waitForDeployment();

  console.log("ChainlinkOracle deployed to:", chainklinkOracle.target);

  console.log(' ');
  console.log('Verifying ChainlinkOracle...');

  try {
    await hre.run('verify:verify', {
      address: chainklinkOracle.target,
      contract: 'contracts/oracles/ChainlinkARBOracle.sol:ChainlinkARBOracle',
      constructorArguments: [
        CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.ARB_SEQUENCER
      ]
    })
  } catch (error) {
    console.log(error)
  }

  // =========================================
  // For Avalanche: Use ChainlinkOracle.sol which does not require passing in anything in deployment
  // =========================================
  // const chainklinkOracle = await ethers.deployContract(
  //   'ChainlinkOracle',
  //   [],
  //   {}
  // );

  // await chainklinkOracle.waitForDeployment();

  // console.log("ChainlinkOracle deployed to:", chainklinkOracle.target);

  // console.log(' ');
  // console.log('Verifying ChainlinkOracle...');

  // try {
  //   await hre.run('verify:verify', {
  //     address: chainklinkOracle.target,
  //     contract: 'contracts/oracles/ChainlinkOracle.sol:ChainlinkOracle',
  //     constructorArguments: []
  //   })
  // } catch (error) {
  //   console.log(error)
  // }

  console.log("Adding price feed for USDC");
  await chainklinkOracle.connect(owner).addTokenPriceFeed(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
    CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.USDC
  )
  console.log("Adding max token deviation for USDC");
  await chainklinkOracle.connect(owner).addTokenMaxDeviation(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
    ethers.parseUnits('0.1', 18)
  )
  console.log("Adding max token delay for USDC");
  await chainklinkOracle.connect(owner).addTokenMaxDelay(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDC,
    86400
  )

  console.log("Adding price feed for ETH");
  await chainklinkOracle.connect(owner).addTokenPriceFeed(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
    CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.ETH
  )
  console.log("Adding max token deviation for ETH");
  await chainklinkOracle.connect(owner).addTokenMaxDeviation(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
    ethers.parseUnits('0.5', 18)
  )
  console.log("Adding max token delay for ETH");
  await chainklinkOracle.connect(owner).addTokenMaxDelay(
    CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WETH,
    86400
  )

  // console.log("Adding price feed for USDCe");
  // await chainklinkOracle.connect(owner).addTokenPriceFeed(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDCe,
  //   CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.USDC
  // )
  // console.log("Adding max token deviation for USDCe");
  // await chainklinkOracle.connect(owner).addTokenMaxDeviation(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDCe,
  //   ethers.parseUnits('0.1', 18)
  // )
  // console.log("Adding max token delay for USDCe");
  // await chainklinkOracle.connect(owner).addTokenMaxDelay(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDCe,
  //   86400
  // )

  // console.log("Adding price feed for USDT");
  // await chainklinkOracle.connect(owner).addTokenPriceFeed(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDT,
  //   CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.USDC
  // )
  // console.log("Adding max token deviation for USDT");
  // await chainklinkOracle.connect(owner).addTokenMaxDeviation(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDT,
  //   ethers.parseUnits('0.1', 18)
  // )
  // console.log("Adding max token delay for USDT");
  // await chainklinkOracle.connect(owner).addTokenMaxDelay(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.USDT,
  //   86400
  // )

  // console.log("Adding price feed for BTC");
  // await chainklinkOracle.connect(owner).addTokenPriceFeed(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WBTC,
  //   CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.BTC
  // )
  // console.log("Adding max token deviation for BTC");
  // await chainklinkOracle.connect(owner).addTokenMaxDeviation(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WBTC,
  //   ethers.parseUnits('0.5', 18)
  // )
  // console.log("Adding max token delay for BTC");
  // await chainklinkOracle.connect(owner).addTokenMaxDelay(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.WBTC,
  //   86400
  // )

  // console.log("Adding price feed for LINK");
  // await chainklinkOracle.connect(owner).addTokenPriceFeed(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.LINK,
  //   CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.LINK
  // )
  // console.log("Adding max token deviation for LINK");
  // await chainklinkOracle.connect(owner).addTokenMaxDeviation(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.LINK,
  //   ethers.parseUnits('0.5', 18)
  // )
  // console.log("Adding max token delay for LINK");
  // await chainklinkOracle.connect(owner).addTokenMaxDelay(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.LINK,
  //   4000
  // )

  // console.log("Adding price feed for UNI");
  // await chainklinkOracle.connect(owner).addTokenPriceFeed(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.UNI,
  //   CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.UNI
  // )
  // console.log("Adding max token deviation for UNI");
  // await chainklinkOracle.connect(owner).addTokenMaxDeviation(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.UNI,
  //   ethers.parseUnits('0.5', 18)
  // )
  // console.log("Adding max token delay for UNI");
  // await chainklinkOracle.connect(owner).addTokenMaxDelay(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.UNI,
  //   86400
  // )

  // console.log("Adding price feed for ARB");
  // await chainklinkOracle.connect(owner).addTokenPriceFeed(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB,
  //   CONSTANTS.CHAIN_ID[42161].CHAINLINK_FEED_ADDRESSES.ARB
  // )
  // console.log("Adding max token deviation for ARB");
  // await chainklinkOracle.connect(owner).addTokenMaxDeviation(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB,
  //   ethers.parseUnits('0.5', 18)
  // )
  // console.log("Adding max token delay for ARB");
  // await chainklinkOracle.connect(owner).addTokenMaxDelay(
  //   CONSTANTS.CHAIN_ID[42161].TOKEN_ADDRESSES.ARB,
  //   86400
  // )


  console.log("===============================");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
