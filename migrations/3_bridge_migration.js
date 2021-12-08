const FINUBridge = artifacts.require("FINUBridge");

module.exports = function (deployer) {
  deployer.deploy(FINUBridge, "", "");
};
