const FAKEONEX = artifacts.require("FAKEONEX");

module.exports = (deployer, network, accounts) => {
  deployer.deploy(FAKEONEX);
};
