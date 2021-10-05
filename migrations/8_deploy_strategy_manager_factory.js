const StrategyManager = artifacts.require("StrategyManager");
const PoolFactory = artifacts.require("PoolFactory");

module.exports = async function(deployer) {
	const strategyInstance = await StrategyManager.deployed();
	const factoryInstance = await PoolFactory.deployed();

	await factoryInstance.upgradeTo(web3.utils.soliditySha3('StrategyManager'), strategyInstance.address);
}