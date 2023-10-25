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

  const DEPLOYING = true // deploying or attaching to deployed contract?
  const ADD_TO_TENDERLY = true // add contracts to tenderly

  let GMXTypes;
  let GMXReader;
  let GMXChecks;
  let GMXWorker;
  let GMXManager;
  let GMXCompound;
  let GMXProcessDeposit;
  let GMXDeposit;
  let GMXProcessWithdraw;
  let GMXWithdraw;
  let GMXRebalance;
  let GMXEmergency;

  if (DEPLOYING) {
    /* Deploy Vault Libraries */

    console.log("Deploying strategy libraries...");

    GMXTypes = await ethers.deployContract('GMXTypes', [], {});
    await GMXTypes.waitForDeployment();
    console.log("GMXTypes library deployed to:", GMXTypes.target);
    try {
      await hre.run('verify:verify', {
        address: GMXTypes.target,
        contract: 'contracts/strategy/gmx/GMXTypes.sol:GMXTypes',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXReader = await ethers.deployContract('GMXReader', [], {});
    await GMXReader.waitForDeployment();
    console.log("GMXReader library deployed to:", GMXReader.target);
    try {
      await hre.run('verify:verify', {
        address: GMXReader.target,
        contract: 'contracts/strategy/gmx/GMXReader.sol:GMXReader',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXChecks = await ethers.deployContract('GMXChecks', [], {
      libraries: {
        GMXReader: GMXReader.target,
      }
    });
    await GMXChecks.waitForDeployment();
    console.log("GMXChecks library deployed to:", GMXChecks.target);
    try {
      await hre.run('verify:verify', {
        address: GMXChecks.target,
        contract: 'contracts/strategy/gmx/GMXChecks.sol:GMXChecks',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXWorker = await ethers.deployContract('GMXWorker', [], {});
    await GMXWorker.waitForDeployment();
    console.log("GMXWorker library deployed to:", GMXWorker.target);
    try {
      await hre.run('verify:verify', {
        address: GMXWorker.target,
        contract: 'contracts/strategy/gmx/GMXWorker.sol:GMXWorker',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXManager = await ethers.deployContract('GMXManager', [], {
      libraries: {
        GMXReader: GMXReader.target,
        GMXWorker: GMXWorker.target,
      }
    });
    await GMXManager.waitForDeployment();
    console.log("GMXManager library deployed to:", GMXManager.target);
    try {
      await hre.run('verify:verify', {
        address: GMXManager.target,
        contract: 'contracts/strategy/gmx/GMXManager.sol:GMXManager',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXCompound = await ethers.deployContract('GMXCompound', [], {
      libraries: {
        GMXChecks: GMXChecks.target,
        GMXManager: GMXManager.target,
        GMXReader: GMXReader.target,
      }
    });
    await GMXCompound.waitForDeployment();
    console.log("GMXCompound library deployed to:", GMXCompound.target);
    try {
      await hre.run('verify:verify', {
        address: GMXCompound.target,
        contract: 'contracts/strategy/gmx/GMXCompound.sol:GMXCompound',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXProcessDeposit = await ethers.deployContract('GMXProcessDeposit', [], {
      libraries: {
        GMXReader: GMXReader.target,
        GMXChecks: GMXChecks.target,
      }
    });
    await GMXProcessDeposit.waitForDeployment();
    console.log("GMXProcessDeposit library deployed to:", GMXProcessDeposit.target);
    try {
      await hre.run('verify:verify', {
        address: GMXProcessDeposit.target,
        contract: 'contracts/strategy/gmx/GMXProcessDeposit.sol:GMXProcessDeposit',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXDeposit = await ethers.deployContract('GMXDeposit', [], {
      libraries: {
        GMXReader: GMXReader.target,
        GMXChecks: GMXChecks.target,
        GMXManager: GMXManager.target,
        GMXProcessDeposit: GMXProcessDeposit.target,
      }
    });
    await GMXDeposit.waitForDeployment();
    console.log("GMXDeposit library deployed to:", GMXDeposit.target);
    try {
      await hre.run('verify:verify', {
        address: GMXDeposit.target,
        contract: 'contracts/strategy/gmx/GMXDeposit.sol:GMXDeposit',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXProcessWithdraw = await ethers.deployContract('GMXProcessWithdraw', [], {
      libraries: {
        GMXReader: GMXReader.target,
        GMXChecks: GMXChecks.target,
        GMXManager: GMXManager.target,
      }
    });
    await GMXProcessWithdraw.waitForDeployment();
    console.log("GMXProcessWithdraw library deployed to:", GMXProcessWithdraw.target);
    try {
      await hre.run('verify:verify', {
        address: GMXProcessWithdraw.target,
        contract: 'contracts/strategy/gmx/GMXProcessWithdraw.sol:GMXProcessWithdraw',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXWithdraw = await ethers.deployContract('GMXWithdraw', [], {
      libraries: {
        GMXReader: GMXReader.target,
        GMXChecks: GMXChecks.target,
        GMXManager: GMXManager.target,
        GMXProcessWithdraw: GMXProcessWithdraw.target,
      }
    });
    await GMXWithdraw.waitForDeployment();
    console.log("GMXWithdraw library deployed to:", GMXWithdraw.target);
    try {
      await hre.run('verify:verify', {
        address: GMXWithdraw.target,
        contract: 'contracts/strategy/gmx/GMXWithdraw.sol:GMXWithdraw',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXRebalance = await ethers.deployContract('GMXRebalance', [], {
      libraries: {
        GMXReader: GMXReader.target,
        GMXChecks: GMXChecks.target,
        GMXManager: GMXManager.target,
      }
    });
    await GMXRebalance.waitForDeployment();
    console.log("GMXRebalance library deployed to:", GMXRebalance.target);
    try {
      await hre.run('verify:verify', {
        address: GMXRebalance.target,
        contract: 'contracts/strategy/gmx/GMXRebalance.sol:GMXRebalance',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    GMXEmergency = await ethers.deployContract('GMXEmergency', [], {
      libraries: {
        GMXChecks: GMXChecks.target,
        GMXManager: GMXManager.target,
      }
    });
    await GMXEmergency.waitForDeployment();
    console.log("GMXEmergency library deployed to:", GMXEmergency.target);
    try {
      await hre.run('verify:verify', {
        address: GMXEmergency.target,
        contract: 'contracts/strategy/gmx/GMXEmergency.sol:GMXEmergency',
        constructorArguments: []
      })
    } catch (error) {
      console.log(error)
    }

    console.log('======================');
    console.log('Contract Addresses');
    console.log('======================');
    console.log(' ');
    console.log(`STRATEGY_GMX_TYPES: '${GMXTypes.target}',`)
    console.log(`STRATEGY_GMX_READER: '${GMXReader.target}',`)
    console.log(`STRATEGY_GMX_CHECKS: '${GMXChecks.target}',`)
    console.log(`STRATEGY_GMX_WORKER: '${GMXWorker.target}',`)
    console.log(`STRATEGY_GMX_MANAGER: '${GMXManager.target}',`)
    console.log(`STRATEGY_GMX_COMPOUND: '${GMXCompound.target}',`)
    console.log(`STRATEGY_GMX_PROCESS_DEPOSIT: '${GMXProcessDeposit.target}',`)
    console.log(`STRATEGY_GMX_DEPOSIT: '${GMXDeposit.target}',`)
    console.log(`STRATEGY_GMX_PROCESSWITHDRAW: '${GMXProcessWithdraw.target}',`)
    console.log(`STRATEGY_GMX_WITHDRAW: '${GMXWithdraw.target}',`)
    console.log(`STRATEGY_GMX_REBALANCE: '${GMXRebalance.target}',`)
    console.log(`STRATEGY_GMX_EMERGENCY: '${GMXEmergency.target}',`)
    console.log(' ');
    console.log('======================');

  }

  if (ADD_TO_TENDERLY) {
    const contracts = [
      {
        display_name: 'GMXTypes',
        address: GMXTypes.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXReader',
        address: GMXReader.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXChecks',
        address: GMXChecks.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXWorker',
        address: GMXWorker.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXManager',
        address: GMXManager.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXCompound',
        address: GMXCompound.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXProcessDeposit',
        address: GMXProcessDeposit.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXDeposit',
        address: GMXDeposit.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXProcessWithdraw',
        address: GMXProcessWithdraw.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXWithdraw',
        address: GMXWithdraw.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXRebalance',
        address: GMXRebalance.target,
        network_id: '42161'
      },
      {
        display_name: 'GMXEmergency',
        address: GMXEmergency.target,
        network_id: '42161'
      },
    ]

    run(contracts);
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
