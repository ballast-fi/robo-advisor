const PoolFactory = artifacts.require("PoolFactory");
const Pool = artifacts.require("Pool");
const IStrategy = artifacts.require("IStrategy");
const IERC20 = artifacts.require("IERC20");

module.exports = async(callback) => {

    const token = process.env.TOKEN;
    const cToken = process.env.CTOKEN;
    const aToken = process.env.ATOKEN;
    try {

        const accounts = await web3.eth.getAccounts();
        const currentAccount = accounts[0];

        const factoryInstance = await PoolFactory.deployed();
        // get latest strategy manager address for the given token
        const strategyManagerAddress = await factoryInstance.poolStrategies(
            web3.utils.soliditySha3(token, web3.utils.soliditySha3('StrategyManager'))
        );

        // get latest pool address for the given token
        const poolAddress = await factoryInstance.poolAddresses(token);

        // get latest compound strategy address for the given token
        const compStrategyAddress = await factoryInstance.poolStrategies(
            web3.utils.soliditySha3(token, web3.utils.soliditySha3('CompoundStrategy'))
        );

        // get latest aave strategy address for the given token
        const aaveStrategyAddress = await factoryInstance.poolStrategies(
            web3.utils.soliditySha3(token, web3.utils.soliditySha3('AaveStrategy'))
        );

        const poolInstance = await Pool.at(poolAddress);
        const tokenInstance = await IERC20.at(token);
        const cTokenInstance = await IERC20.at(cToken);
        const aTokenInstance = await IERC20.at(aToken);

        const compPool = await IStrategy.at(compStrategyAddress);
        const aavePool = await IStrategy.at(aaveStrategyAddress);

        const aavePoolAPR = await aavePool.getAPR();
        const compPoolAPR = await compPool.getAPR();

        const balanceInAccount = await tokenInstance.balanceOf(currentAccount);
        const balanceInManager = await tokenInstance.balanceOf(strategyManagerAddress);

        const balanceInCompStrategy = await tokenInstance.balanceOf(compStrategyAddress);
        const cTokenBalanceInStrategy = await cTokenInstance.balanceOf(compStrategyAddress);
        const cTokenBalanceInManager = await cTokenInstance.balanceOf(strategyManagerAddress);

        const balanceInAaveStrategy = await tokenInstance.balanceOf(compStrategyAddress);
        const aTokenBalanceInStrategy = await aTokenInstance.balanceOf(aaveStrategyAddress);
        const aTokenBalanceInManager = await aTokenInstance.balanceOf(strategyManagerAddress);

        const compBalance = await compPool.investedUnderlyingBalance();
        const aaveBalance = await aavePool.investedUnderlyingBalance();

        const underlyingBalanceInPool = await poolInstance.underlyingBalanceInPool();
        const underlyingBalanceInStrategy = await poolInstance.underlyingBalanceInclStrategy();
        const apr = await poolInstance.getAPR();
        console.log(' APR ' + apr);
        console.log('balanceInAccount:', balanceInAccount.toString());
        console.log('underlyingBalanceInPool:', underlyingBalanceInPool.toString());
        console.log('underlyingBalanceIncludeStrategy:', underlyingBalanceInStrategy.toString());
        console.log('balanceInManager:', balanceInManager.toString());

        console.log('balanceInCompStrategy:', balanceInCompStrategy.toString());
        console.log('cTokenBalanceInStrategy:', cTokenBalanceInStrategy.toString());
        console.log('cTokenBalanceInManager:', cTokenBalanceInManager.toString());
        console.log('compInvestedUnderlyingBalance:', compBalance.toString());
        console.log('compAPR:', compPoolAPR.toString());

        console.log('balanceInAaveStrategy:', balanceInAaveStrategy.toString());
        console.log('aTokenBalanceInStrategy:', aTokenBalanceInStrategy.toString());
        console.log('aTokenBalanceInManager:', aTokenBalanceInManager.toString());
        console.log('aaveInvestedUnderlyingBalance:', aaveBalance.toString());
        console.log('aaveAPR:', aavePoolAPR.toString());


    } catch (error) {
        console.log(error);
    }
    callback();
}