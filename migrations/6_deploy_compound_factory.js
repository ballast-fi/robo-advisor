const CompoundStrategy = artifacts.require("CompoundStrategy");
const PoolFactory = artifacts.require("PoolFactory");

module.exports = async function(deployer) {
	const strategyInstance = await CompoundStrategy.deployed();
	const factoryInstance = await PoolFactory.deployed();

	await factoryInstance.upgradeTo(web3.utils.soliditySha3('CompoundStrategy'), strategyInstance.address);
}