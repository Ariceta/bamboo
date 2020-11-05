const Factory = artifacts.require('uniswapv2/UniswapV2Factory.sol');
const WETH = artifacts.require('weth/WETH.sol');
const Router = artifacts.require('uniswapv2/UniswapV2Router02.sol')


module.exports = async function (deployer, _network, addresses) {
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

    // Deploy factory. Don't forget to change the initCodeHash before deploy!!!
    console.log("Deploying factory...")
    await deployer.deploy(Factory, addresses[0]);
    const factory = await Factory.deployed();
    console.log("Factory addr: " + factory.address)

    // Deploy Router
    console.log("Deploying router...")
    await deployer.deploy(Router, factory.address, weth.address)
    const router = await Router.deployed();
    console.log("Router addr: " + router.address)


};
