const Pool = artifacts.require("Pool");
const PoolFactory = artifacts.require("PoolFactory");

module.exports = async(callback) => {

    const token = process.env.TOKEN
    try {

        if (!token) {
            throw new Error('Invalid underlying token');
        }
        const factoryInstance = await PoolFactory.deployed();
        // get latest strategy manager address for the given token
        const strategyAddress = await factoryInstance.poolStrategies(
            web3.utils.soliditySha3(token, web3.utils.soliditySha3('StrategyManager'))
        );

        const receipt = await factoryInstance.createPool(token, web3.utils.soliditySha3('Pool'), strategyAddress);
        console.log('receipt:', receipt);
    } catch (error) {
        console.log(error);
    }
    callback();
}