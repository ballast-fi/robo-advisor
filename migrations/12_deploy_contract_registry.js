const ContractRegistry = artifacts.require("ContractRegistry");

const PoolFactory = artifacts.require("PoolFactory");
const PriceOracle = artifacts.require("PriceOracle");

module.exports = async function(deployer) {
	await deployer.deploy(ContractRegistry);

	const poolFactoryInstance = await PoolFactory.deployed();
    const priceOracleInstance = await PriceOracle.deployed();

	const registryInstance = await ContractRegistry.deployed();
	await registryInstance.importContracts(
		[poolFactoryInstance.address, priceOracleInstance.address]
	);
}