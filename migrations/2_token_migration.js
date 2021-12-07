const FINU = artifacts.require("FINU");

const secret = require("../secret.json");
const secretTestnet = require("../secret.testnet.json");

module.exports = function (deployer) {
  if (network == "mainnet") {
    deployer.deploy(
      FINU,
      secret.treasuryWalletAddress,
      secret.yieldWalletAddress,
      secret.feeAddrWallet1,
      secret.feeAddrWallet2,
      secret.pancakeSwapRouterAddress
    );
  } else {
    deployer.deploy(
      FINU,
      secretTestnet.treasuryWalletAddress,
      secretTestnet.yieldWalletAddress,
      secretTestnet.feeAddrWallet1,
      secretTestnet.feeAddrWallet2,
      secretTestnet.pancakeSwapRouterAddress
    );
  }
};