const AaveStrategy = artifacts.require("AaveStrategy");
const PoolFactory = artifacts.require("PoolFactory");

module.exports = async function(deployer) {
	const strategyInstance = await AaveStrategy.deployed();
	const factoryInstance = await PoolFactory.deployed();

	await factoryInstance.upgradeTo(web3.utils.soliditySha3('AaveStrategy'), strategyInstance.address);
}