// deploy/00_deploy_your_contract.js

const { ethers } = require("hardhat");
const contract_names = ["RealEstate"]
module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // Deploy First
  // const First = await ethers.getContractFactory('FirstContract');
  // const first = await First.deploy();
  console.log("deployer")
  console.log(deployer)

  console.log(`chainId: ${chainId}`)
  
  for (const c_name in contract_names){
    await deploy(c_name, {
      // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
      from: deployer,
      // args: [ "Hello", ethers.utils.parseEther("1.5") ],
      log: true,
    });  
  }
  

  // Getting a previously deployed contract
  // const yourCollectible = await ethers.getContract("YourCollectible", deployer);

  // ToDo: Verify your contract with Etherscan for public chains
  // if (chainId !== "31337") {
  //   try {
  //     console.log(" 🎫 Verifing Contract on Etherscan... ");
  //     await sleep(3000); // wait 3 seconds for deployment to propagate bytecode
  //     await run("verify:verify", {
  //       address: yourCollectible.address,
  //       contract: "contracts/YourCollectible.sol:YourCollectible",
  //       // contractArguments: [yourToken.address],
  //     });
  //   } catch (e) {
  //     console.log(" ⚠️ Failed to verify contract on Etherscan ");
  //   }
  // }
};

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports.tags = contract_names;
