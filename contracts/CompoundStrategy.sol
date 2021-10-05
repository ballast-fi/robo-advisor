// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/ComptrollerInterface.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/CERC20.sol";
import "./interfaces/IPool.sol";

/// @title  CompoundStrategy
/// @notice Strategy that invests the underlying token into Compound.
///         The strategy is owned by the underlying token pool.
/// @dev    needs to be upgradeable, so that it complies with the beacon proxy pattern.
contract CompoundStrategy is IStrategy, OwnableUpgradeable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 private constant ONE_18 = 10**18;

    /// @notice COMP reward token
    address public compToken;

    /// @notice comptroller
    address public comptroller;

    /// @notice Protocol token address
    address public protocolToken;

    /// @notice Underlying token address
    address public override underlying;

    /// @notice contract registry
    IContractRegistry public contractRegistry;

    /// @notice Blocks per year
    uint256 public blocksPerYear;

    //  @notice uniswap router
    address public uniswapRouterV2;

    uint256 public rewardThreshold;

    /// @dev only pool controllers
    modifier onlyController() {
        address poolAddress = contractRegistry.poolFactory().poolAddresses(underlying);
        require(msg.sender == IPool(poolAddress).underlyingStrategy()
            || msg.sender == poolAddress
            || msg.sender == owner(),
            "NOT_POOL_CONTROLLER");
        _;
    }

    /// @notice Initialize the contract instead of a constructor during deployment.
    /// @param  _underlying Underlying token address
    /// @param  _registry Contract registry address
    /// @param  _owner Contract owner
    /// @param  _data init data
    function initialize(address _underlying, address _registry, address _owner, bytes memory _data)
    external override initializer {

        require(_underlying != address(0) && _owner != address(0) && _registry != address(0), "ZERO_ADDRESS");

        (address _token, address _comp, address _comptroller, address _uniswapRouterV2) = abi.decode(
        _data, (address, address, address, address));

        OwnableUpgradeable.__Ownable_init();

        protocolToken = _token;
        underlying = _underlying;
        compToken = _comp;
        comptroller = _comptroller;
        uniswapRouterV2 = _uniswapRouterV2;
        contractRegistry = IContractRegistry(_registry);
        rewardThreshold = 1 * (10 ** uint256(18));

        blocksPerYear = 2371428;

        transferOwnership(_owner);
    }

    /// @notice Redeems protocol tokens for underlying tokens.
    ///         This method assumes the protocol tokens are already available in this contract.
    /// @param  _redeemAmount shares amount to redeem.
    /// @param  _totalSupply total shares.
    /// @param  _account address to send redeemed tokens to.
    //  @return tokens redeemed.
    function redeem(uint256 _redeemAmount, uint256 _totalSupply, address _account) external override onlyController
    returns (uint256 tokens) {

        require(_redeemAmount <= _totalSupply, "ERR_REDEEM_COMP");

        CERC20 _cToken = CERC20(protocolToken);
        IERC20 _underlying = IERC20(underlying);

        uint256 cTokensToRedeem = _redeemAmount.mul(_protocolTokenBalanceOf()).div(_totalSupply);

        require(_protocolTokenBalanceOf() >= cTokensToRedeem, "NO_FUNDS");
        require(_cToken.redeem(cTokensToRedeem) == 0, "ERR_REDEEM");

        tokens = _underlyingBalanceOf();
        _underlying.safeTransfer(_account, tokens);
    }

    /// @notice Execute a rebalance by liquidating the gov rewards and reinvesting into the protocol.
    function rebalance(bytes memory _data) external override onlyController {
        _liquidateReward();
        _mint();
    }

    /// @notice Amount of the underlying token invested in protocol token.
    /// @return uint256 underlying balance.
    function investedUnderlyingBalance() external override view returns (uint256) {
        return CERC20(protocolToken).exchangeRateStored().mul(
            _protocolTokenBalanceOf()).div(ONE_18);
    }

    /// @notice APR for the current protocol token
    function getAPR() external override view returns (uint256 apr) {
        CERC20 cToken = CERC20(protocolToken);
        uint256 cRate = cToken.supplyRatePerBlock();
        apr = cRate.mul(blocksPerYear).mul(100);
        apr += getGovAPR();
    }

    /// @notice Mints new protocol tokens in the strategy for underlying tokens.
    ///         This method assumes the underlying tokens were already transferred to this strategy.
    /// @return cTokens protocol tokens minted
    function _mint() internal returns (uint256 cTokens) {
        uint256 balance = _underlyingBalanceOf();
        if (balance == 0) {
            return cTokens;
        }
        // get a handle for the corresponding cToken contract
        CERC20 _cToken = CERC20(protocolToken);
        IERC20(underlying).safeApprove(protocolToken, 0);
        IERC20(underlying).safeApprove(protocolToken, balance);
        // mint the cTokens and assert there is no error
        require(_cToken.mint(balance) == 0, "ERR_MINT");
        // cTokens are now in this contract
        // TODO maybe send them to the sender
    }

    function _liquidateReward() internal {

        address[] memory assets = new address[](1);
        assets[0] = protocolToken;
        ComptrollerInterface(comptroller).claimComp(address(this), assets);
        uint256 balance = _compTokenBalanceOf();

        if (balance < rewardThreshold) {
            return;
        }

        uint256 amountOutMin = 1;
        IERC20(compToken).safeApprove(address(uniswapRouterV2), 0);
        IERC20(compToken).safeApprove(address(uniswapRouterV2), balance);
        address[] memory path = new address[](3);
        path[0] = compToken;
        path[1] = IUniswapV2Router02(uniswapRouterV2).WETH();
        path[2] = underlying;
        IUniswapV2Router02(uniswapRouterV2).swapExactTokensForTokens(
            balance,
            amountOutMin,
            path,
            address(this),
            block.timestamp
            );
    }

    /// @notice Amount of the protocol tokens owned by this contact.
    /// @return uint256 protocol token balance
    function _protocolTokenBalanceOf() internal view returns (uint256) {
        return IERC20(protocolToken).balanceOf(address(this));
    }

    /// @notice Amount of the underlying tokens owned by this contact.
    /// @return uint256 underlying balance
    function _underlyingBalanceOf() internal view returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }

    /// @notice Amount of the underlying tokens owned by this contact.
    /// @return uint256 underlying balance
    function _compTokenBalanceOf() internal view returns (uint256) {
        return IERC20(compToken).balanceOf(address(this));
    }

    /// @notice APR for the governance token expressed in underlying
    function getGovAPR() internal view returns (uint256 govAPR) {
        CERC20 _cToken = CERC20(protocolToken);
        uint256 compSpeeds = ComptrollerInterface(comptroller).compSpeeds(protocolToken);
        uint256 cTokenNAV = _cToken.exchangeRateStored().mul(IERC20(protocolToken).totalSupply()).div(ONE_18);
        // how much costs 1COMP in token (1e(_token.decimals()))
        uint256 compUnderlyingPrice = contractRegistry.priceOracle().getPriceToken(compToken, underlying);
        // mul(100) needed to have a result in the format 4.4e18
        return compSpeeds.mul(compUnderlyingPrice).mul(blocksPerYear).mul(100).div(cTokenNAV);
    }
}