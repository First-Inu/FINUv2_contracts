const FINU = artifacts.require("FINU");
const FINUBridge = artifacts.require("FINUBridge");

const secret = require("../secret.json");
const secretTestnet = require("../secret.testnet.json");

module.exports = function (deployer, network) {
  if (network == "mainnet") {
    await deployer.deploy(
      FINU,
      secret.treasuryWalletAddress,
      secret.yieldWalletAddress,
      secret.feeAddrWallet1,
      secret.feeAddrWallet2,
      secret.pancakeSwapRouterAddress
    );

    const token = await FINU.deployed();
    await deployer.deploy(
      FINUBridge,
      token.address,
      secret.backendWallet
    );
    
  } else {
    await deployer.deploy(
      FINU,
      secretTestnet.treasuryWalletAddress,
      secretTestnet.yieldWalletAddress,
      secretTestnet.feeAddrWallet1,
      secretTestnet.feeAddrWallet2,
      secretTestnet.pancakeSwapRouterAddress
    );

    const token = await FINU.deployed();
    await deployer.deploy(
      FINUBridge,
      token.address,
      secretTestnet.backendWallet
    );
  }
};