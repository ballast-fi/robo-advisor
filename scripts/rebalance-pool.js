const Pool = artifacts.require("Pool");
const PoolFactory = artifacts.require("PoolFactory");

module.exports = async(callback) => {

    const token = process.env.TOKEN;
    try {

        if (!token) {
            throw new Error('Invalid underlying token');
        }

        const factoryInstance = await PoolFactory.deployed();
        // get latest pool address for the given token
        const poolAddress = await factoryInstance.poolAddresses(token);
        const poolInstance = await Pool.at(poolAddress);
        const _underlyingStrategy = await poolInstance.underlyingStrategy();

        // build the pool data respecting the strategy chain
        const _strategyData = '0x';
        const _managerData = web3.eth.abi.encodeParameters(['uint256[]', 'bytes'],
            [[20000000, 80000000], _strategyData]);
        const _poolData = web3.eth.abi.encodeParameters(['uint256', 'address', 'bytes'],
            [90000000, _underlyingStrategy, _managerData]);

        const estimatedGasUsage = await poolInstance.rebalance.estimateGas(_poolData);
        console.log('estimatedGasUsage:', estimatedGasUsage);

        const receipt = await poolInstance.rebalance(_poolData);
        console.log('receipt:', receipt);

    } catch (error) {
        console.log(error);
    }
    callback();
}