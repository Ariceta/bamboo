const Bamboo = artifacts.require('token/BambooToken.sol');
const MasterChef = artifacts.require('masterchef/MasterChef.sol')



module.exports = async function (deployer, _network, addresses) {
  // Deploy BambooToken
  console.log("Deploying bamboo...")
  await deployer.deploy(Bamboo);
  const bamboo = await Bamboo.deployed()
  bamboo.mint(addresses[0], web3.utils.toWei('8666666'))
  console.log("Bamboo addr: " + bamboo.address)


  // Deploy MasterChef
  //const bamboo = await Bamboo.at('0x721DEF2bDe249A02a6C49f9Bd4022c1aa1bE549f');
  console.log("Deploying MasterChef...")

  await deployer.deploy(
      MasterChef,
      bamboo.address,
      addresses[0],
      web3.utils.toWei('100'),
      1,
      1
  );
  const masterChef = await MasterChef.deployed();
  await bamboo.proposeOwner(masterChef.address);
  await masterChef.claimToken(bamboo.address);

  /**/
  /*// Deploy Migrator
  console.log("Deploying Migrator...")
  await deployer.deploy(Migrator, "0x827f2046f0065b9ad4A6955F1F737ab2D32395Ae", "0x57E3b755195DD406059a4a3F4A0542278A476720")
  const migrator = await Migrator.deployed();
  console.log("Migrator addr: " + migrator.address)*/


};
