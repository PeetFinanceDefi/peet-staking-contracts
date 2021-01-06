const PeetStakingContract = artifacts.require("PeetStakingContract");

module.exports = function(deployer) {
  deployer.deploy(PeetStakingContract, "0x03a2c6731A70611ffC486207129DD3f8DECb0a65");
};
