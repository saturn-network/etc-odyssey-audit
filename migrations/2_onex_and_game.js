const ONEX = artifacts.require("ONEX");
const ETCOdyssey = artifacts.require("ETCOdyssey");
const OriginalETCOdyssey = artifacts.require("OriginalETCOdyssey");

module.exports = (deployer, network, accounts) => {
  deployer.deploy(ONEX).then(() => {
    return deployer.deploy(OriginalETCOdyssey, ONEX.address).then(() => {
      return deployer.deploy(ETCOdyssey, ONEX.address);
    });
  });
};
