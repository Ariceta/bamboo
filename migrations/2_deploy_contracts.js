const Factory = artifacts.require('uniswapv2/uniswap-factory/UniswapV2Factory.sol');
const Bamboo = artifacts.require('token/BambooToken.sol');
const WETH = artifacts.require('weth/WETH.sol');
const Router = artifacts.require('uniswapv2/uniswap-router/UniswapV2Router02.sol')


module.exports = async function(deployer, _network, addresses) {
  
  if(_network === 'ropsten') {
    /* Deploy BambooToken if not on testnet
      await deployer.deploy(Bamboo);
      const bamboo = await Bamboo.deployed()
      bamboo.mint(addresses[0], web3.utils.toWei('8666666'))
    */

    // Get WETH contact in ropsten
    weth = await WETH.at('0xc778417E063141139Fce010982780140Aa0cD5Ab');

    // Deploy Factory
    await deployer.deploy(Factory, addresses[0]);
    const factory = await Factory.deployed();
    
    // Deploy Router
    await deployer.deploy(Router, factory.address, WETH.address)
    const router = await Router.deployed();

  } else {

    // Deploy WETH contract 
    await deployer.deploy(WETH);
    const weth = await WETH.deployed();
  
    // Deploy bamboo and mint the pre-mine
    await deployer.deploy(Bamboo);
    const bamboo = await Bamboo.deployed()
    bamboo.mint(addresses[0], web3.utils.toWei('8666666'))
  
    // Deploy factory
    await deployer.deploy(Factory, addresses[0]);
    const factory = await Factory.deployed();
  
    // Deploy Router
    await deployer.deploy(Router, factory.address, WETH.address)
    const router = await Router.deployed();
  }


  /*
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
