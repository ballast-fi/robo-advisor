const PriceOracle = artifacts.require("PriceOracle");

module.exports = async function(deployer) {
	await deployer.deploy(PriceOracle);
}