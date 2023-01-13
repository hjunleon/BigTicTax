const { ethers } = require("hardhat");
const { keccak256 } =  require("@ethersproject/keccak256");
const { toUtf8Bytes } =  require("@ethersproject/strings");

const contract_name = "RealEstate"

isLocalhost = true;

const main_authority = "Gahmen";

const estates = [
    {
        "owner":{
            "addr":"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            "name": main_authority,
            "age": 58,
        },
        "property":{
            "physical_addr":"Blk 123, Serangoon St 15, #05-31",
            "postal_code":"S519000",
            "unit_num": '#05-31'
        },
        "duration": 0, // in days
        "own_date": 0
    },
    {
        "owner":{
            "addr":"0x70997970c51812dc3a010c7d01b50e0d17dc79c8",
            "name": "John", // non owners could be the home buyer or private home sellers, just that the central authority mint for them.
            "age": 22,
        },
        "property":{
            "physical_addr":"Blk 124, Serangoon St 15, #05-31",
            "postal_code":"S519000",
            "unit_num": '#05-31'
        },
        "duration": 1 * 31 * 24, // in days
        "own_date": 1670716800
    }   
]

async function main() {
    
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();

    console.log("deployer")
    console.log(deployer)

    console.log(`chainId: ${chainId}`)
    const curContract = await ethers.getContract(contract_name, deployer);
    console.log(`Your contract is deployed to :${curContract.address}`);
    const network = await curContract.provider.getNetwork();
    console.log(network); 
    for (const estate of estates){
        const signature = keccak256(toUtf8Bytes(estate.property.physical_addr));
        console.log(`signature: ${signature}`)
        // this signature will form the URI url
        await curContract.addProperty(estate.owner.addr,signature, {
            gasLimit: 30000000//1e10
        });
    }
    let price, taxes;
    price, taxes = await curContract.getPrice();
    console.log(`price: ${price}`);
    console.log(`taxes: ${taxes}`)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });