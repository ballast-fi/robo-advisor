const Pool = artifacts.require("Pool");
const PoolFactory = artifacts.require("PoolFactory");
const StrategyManagerFactory = artifacts.require("StrategyManagerFactory");
const StrategyManager = artifacts.require("StrategyManager");

module.exports = async(callback) => {

    const token = process.env.TOKEN;
    try {

        if (!token) {
            throw new Error('Invalid underlying token');
        }

        const strategyManagerFactoryInstance = await StrategyManagerFactory.deployed();
        // get latest strategy address for the given token
        const strategyManagerAddress = await strategyManagerFactoryInstance.strategyManagers(token);
        const strategyManagerInstance = await StrategyManager.at(strategyManagerAddress);

        await strategyManagerInstance.setAllocation([100000000, 0]);

        const factoryInstance = await PoolFactory.deployed();
        // get latest pool address for the given token
        const poolAddress = await factoryInstance.poolAddresses(token);
        const poolInstance = await Pool.at(poolAddress);

        // build the pool data respecting the strategy chain
        const _strategyData = '0x';
        const _managerData = web3.eth.abi.encodeParameters(['uint256[]', 'bytes'],
            [[0, 100000000], _strategyData]);
        const _poolData = web3.eth.abi.encodeParameters(['uint256', 'bytes'],
            [100000000, _managerData]);

        const estimatedGasUsage = await poolInstance.rebalance.estimateGas(_poolData);
        console.log('estimatedGasUsage:', estimatedGasUsage);

        const receipt = await poolInstance.rebalance(_poolData);
        console.log('receipt:', receipt);

    } catch (error) {
        console.log(error);
    }
    callback();
}