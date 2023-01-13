const { ethers } = require("hardhat");
const contract_names = ["RealEstate"]
async function main() {
    const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // Deploy First
  // const First = await ethers.getContractFactory('FirstContract');
  // const first = await First.deploy();
  console.log("deployer")
  console.log(deployer)

  console.log(`chainId: ${chainId}`)
  
  for (const c_name of contract_names){
    console.log(`c_name: ${c_name}`)
    await deploy(c_name, {
      // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
      from: deployer,
      // args: [ "Hello", ethers.utils.parseEther("1.5") ],
      log: true,
      args: ["Public_House","HDB","http://localhost:9000/api/property_details/"]
    });  
    const curContract = await ethers.getContract(c_name, deployer);
    console.log(`Your contract is deployed to :${curContract.address}`)
  }
  
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });