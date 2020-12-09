const PeetStakingContract = artifacts.require("PeetStakingContract");

module.exports = function(deployer) {
  deployer.deploy(PeetStakingContract, "0x8984e422E30033A84B780420566046d25EB3519a");
};
