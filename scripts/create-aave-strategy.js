const PoolFactory = artifacts.require("PoolFactory");
const ContractRegistry = artifacts.require("ContractRegistry");

module.exports = async(callback) => {

    const token = process.env.TOKEN;
    const aToken = process.env.ATOKEN;
    const addressProvider = process.env.AAVE_PROVIDER;
    const uniswapRouterV2 = process.env.UNISWAP_ROUTER_V2;
    try {

        if (!aToken) {
            throw new Error('Invalid Aave token');
        }

        if (!token) {
            throw new Error('Invalid underlying token');
        }


        const factoryInstance = await PoolFactory.deployed();
        const registryInstance = await ContractRegistry.deployed();
        const predictedControllerAddress = await factoryInstance.getStrategyAddress(
            web3.utils.soliditySha3('StrategyManager')
        );

        // init data for L2 token
        const _data = web3.eth.abi.encodeParameters(['address', 'address', 'address'],
            [aToken, addressProvider, uniswapRouterV2]);

        const receipt = await factoryInstance.createStrategy(
            token, web3.utils.soliditySha3('AaveStrategy'),
            registryInstance.address, predictedControllerAddress, _data
        );
        console.log('receipt:', receipt);
    } catch (error) {
        console.log(error);
    }
    callback();
}