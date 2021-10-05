const Pool = artifacts.require("Pool");
const PoolFactory = artifacts.require("PoolFactory");

module.exports = async function(deployer) {
	const poolInstance = await Pool.deployed();
	await deployer.deploy(PoolFactory);

	const factoryInstance = await PoolFactory.deployed();
	await factoryInstance.upgradeTo(web3.utils.soliditySha3('Pool'), poolInstance.address)
}