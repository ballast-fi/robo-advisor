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

        await poolInstance.setMaxInvestmentPerc(100000000);

        const receipt = await poolInstance.rebalance();
        console.log('receipt:', receipt);

    } catch (error) {
        console.log(error);
    }
    callback();
}