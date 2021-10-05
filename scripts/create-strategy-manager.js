const PoolFactory = artifacts.require("PoolFactory");
const ContractRegistry = artifacts.require("ContractRegistry");

module.exports = async(callback) => {

    const token = process.env.TOKEN
    try {

        if (!token) {
            throw new Error('Invalid underlying token');
        }


        const strategyFactoryInstance = await PoolFactory.deployed();

        const compStrategyAddress = await strategyFactoryInstance.poolStrategies(
            web3.utils.soliditySha3(token, web3.utils.soliditySha3('CompoundStrategy'))
        );
        const aaveStrategyAddress = await strategyFactoryInstance.poolStrategies(
            web3.utils.soliditySha3(token, web3.utils.soliditySha3('AaveStrategy'))
        );
        const predictedControllerAddress = await strategyFactoryInstance.getStrategyAddress(
            web3.utils.soliditySha3('Pool')
        );

        const _data = web3.eth.abi.encodeParameters(['address[]'],
            [[compStrategyAddress, aaveStrategyAddress]]);

        const registryInstance = await ContractRegistry.deployed();
        const receipt = await strategyFactoryInstance.createStrategy(
            token, web3.utils.soliditySha3('StrategyManager'),
            registryInstance.address, predictedControllerAddress, _data
        );
        console.log('receipt:', receipt);
    } catch (error) {
        console.log(error);
    }
    callback();
}