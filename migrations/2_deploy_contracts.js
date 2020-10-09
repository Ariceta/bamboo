const Factory = artifacts.require('uniswapv2/uniswap-factory/UniswapV2Factory.sol');
const Sushi = artifacts.require('token/SushiToken.sol');
const WETH = artifacts.require('weth/WETH.sol');
const Router = artifacts.require('uniswapv2/uniswap-router/UniswapV2Router02.sol')


module.exports = async function(deployer, _network, addresses) {


  await deployer.deploy(WETH);
  const weth = await WETH.deployed();

  await deployer.deploy(Sushi);
  const sushi = await Sushi.deployed()
  sushi.mint(addresses[0], web3.utils.toWei('1000'))

  await deployer.deploy(Factory, addresses[0]);
  const factory = await Factory.deployed();

  await factory.createPair(weth.address, sushi.address);

  await deployer.deploy(Router, factory.address, WETH.address)
  const router = await Router.deployed();
  
  /*

  */


  /*


  

  
  await deployer.deploy(Factory, admin);
  const factory = await Factory.deployed();
  await factory.createPair(weth.address, tokenA.address);
  await factory.createPair(weth.address, tokenB.address);
  await deployer.deploy(Router, factory.address, "0x74Cd334a4A6A121d47481689F2f8350156c111FF");

  */
  /*
  const router = await Router.deployed();

  await deployer.deploy(SushiToken);
  const sushiToken = await SushiToken.deployed();

  await deployer.deploy(
    MasterChef,
    sushiToken.address,
    admin,
    web3.utils.toWei('100'),
    1,
    1
  );
  const masterChef = await MasterChef.deployed();
  await sushiToken.transferOwnership(masterChef.address);

  await deployer.deploy(SushiBar, sushiToken.address);
  const sushiBar = await SushiBar.deployed();

  await deployer.deploy(
    SushiMaker,
    factory.address, 
    sushiBar.address, 
    sushiToken.address, 
    weth.address
  );
  const sushiMaker = await SushiMaker.deployed();
  await factory.setFeeTo(sushiMaker.address);

  await deployer.deploy(
    Migrator,
    masterChef.address,
    '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
    factory.address,
    1
  );*/
};