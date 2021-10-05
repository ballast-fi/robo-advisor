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

        const _data = web3.eth.abi.encodeParameters(['uint256[]', 'address[]'],
            [[60000000, 40000000], [compStrategyAddress, aaveStrategyAddress]]);

        const registryInstance = await ContractRegistry.deployed();
        const receipt = await strategyFactoryInstance.createStrategy(
            token, web3.utils.soliditySha3('StrategyManager'),
            registryInstance.address, _data
        );
        console.log('receipt:', receipt);
    } catch (error) {
        console.log(error);
    }
    callback();
}