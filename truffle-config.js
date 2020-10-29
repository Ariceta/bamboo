const { projectId, mnemonic } = require('./secrets.json');
const Web3 = require('web3');
const web3 = new Web3();
var HDWalletProvider = require("truffle-hdwallet-provider");

module.exports = {
  // Uncommenting the defaults below
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  //
  networks: {
  development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
  },
  ropsten: {
    provider: function() {
      return new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/${projectId}`)
    },
    network_id: 3,
    gas: 7000000      //make sure this gas allocation isn't over 4M, which is the max
  },
  kovan: {
    provider: function() {
      return new HDWalletProvider(mnemonic, `https://kovan.infura.io/v3/${projectId}`)
    },
    network_id: 42,
    gas: 7000000      //make sure this gas allocation isn't over 4M, which is the max
  },
  live: {
    provider: function() {
      return new HDWalletProvider(mnemonic, `https://mainnet.infura.io/v3/${projectId}`)
    },
    network_id: 1,
    gas: 3000000,      //make sure this gas allocation isn't over 4M, which is the max
    gasPrice: web3.utils.toWei('16', 'gwei')

  }
  //  test: {
  //    host: "127.0.0.1",
  //    port: 7545,
  //    network_id: "*"
  //  }
  },
  //
  compilers: {
    solc: {
      version: "0.6.12",
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    }

  }
};


