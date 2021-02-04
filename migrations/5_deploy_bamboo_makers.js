const BField = artifacts.require("BambooField.sol");
const BFarmer = artifacts.require("BambooFarmer.sol");
const Bamboo = artifacts.require('token/BambooToken.sol');
const UniswapV2Factory = artifacts.require('uniswapv2/UniswapV2Factory.sol');
const ZooKeeper = artifacts.require('ZooKeeper.sol')
const WETH = artifacts.require('token/WETH.sol');


module.exports = async function (deployer, _network, addresses) {
    let bamboo = await Bamboo.deployed();
    let factory =  await UniswapV2Factory.deployed();
    let keeper = await ZooKeeper.deployed();

    let weth;
    if(_network === 'kovan') {
        weth = await WETH.at('0xd0A1E359811322d97991E03f863a0C30C2cF029C');
    }
    else if (_network === 'live') {
        weth = await WETH.at('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2');
    }
    else{
        // Deploy WETH contract
        await deployer.deploy(WETH);
        weth = await WETH.deployed();
    }

    // Deploy BambooField
    console.log("Deploying BambooField...")
    await deployer.deploy(
        BField,
        bamboo.address,
        keeper.address,
        '10', '604800',
    );
    const field = await BField.deployed();
    console.log(field.address);
    console.log("BambooField deployed!")

    // Deploy BambooFarmer
    console.log("Deploying BambooFarmer...")
    await deployer.deploy(
        BFarmer,
        factory.address,
        field.address,
        bamboo.address,
        weth.address,
        addresses[0]
    );
    const farmer = await BFarmer.deployed();
    console.log(farmer.address);
    console.log("BambooFarmer deployed!")
};
