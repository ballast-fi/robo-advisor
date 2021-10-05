// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IContractRegistry.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/CERC20.sol";

contract StrategyManager is IStrategy, OwnableUpgradeable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 private constant FULL_ALLOC = 100000000; // 100%
    uint256 private constant MARGIN_ALLOC = 1000000; // 1%

    /// @notice underlying token of the pool
    address public override underlying;

    /// @notice Weighted allocations per pool. The index of the array determines the allocation strategy.
    ///         The value at the index determines the weight assigned to that strategy.
    /// @dev    indexes: 0 - Compound; 1 - Aave; 2 - Yearn
    uint256[] public executedAllocation;

    //  @notice Strategy addresses
    /// @dev    0   -   CompoundStrategy; 1  - AaveStrategy; 2  -  YearnStrategy
    address[] public underlyingStrategy;

    /// @notice contract registry
    IContractRegistry public contractRegistry;

    /// @notice strategy controller
    address public controller;

    /// @notice Initialize the contract instead of a constructor during deployment.
    /// @param  _underlying Underlying token address
    /// @param  _registry Contract registry address
    //  @param  _owner Contract owner
    /// @param  _data strategy init data
    function initialize(address _underlying, address _registry, address _controller,
        address _owner, bytes memory _data)
        external override initializer {

        require(_underlying != address(0) && _owner != address(0)
                && _registry != address(0), "ZERO_ADDRESS");

        OwnableUpgradeable.__Ownable_init();

        (address[] memory _strategies) = abi.decode(_data, (address[]));

        underlying = _underlying;
        contractRegistry = IContractRegistry(_registry);

        underlyingStrategy = _strategies;
        controller = _controller;

        transferOwnership(_owner);
    }

    /// @dev only pool controllers
    modifier onlyController() {
        require(msg.sender == controller
            || msg.sender == owner(),
            "NOT_POOL_CONTROLLER");
        _;
    }

    function redeem(uint256 _redeemAmount, uint256 _totalSupply, address _account)
    external override onlyController returns (uint256 redeemedTokens) {

        require(_redeemAmount <= _totalSupply, "ERR_REDEEM_MANAGER");
        redeemedTokens = _redeemInternal(_redeemAmount, _totalSupply, _account);
    }

    function rebalance(bytes memory _data) external override onlyController {

        (uint256[] memory _allocations, 
        bytes memory _underlyingData) = abi.decode(_data, (uint256[], bytes));

        uint256 lastLen = executedAllocation.length;
        require(_allocations.length >= lastLen, "ERR_ALLOCATION_LENGTH");

        // compare the allocations
        bool areAllocationsEqual = _allocations.length == lastLen;
        if (areAllocationsEqual) {
            for (uint256 i = 0; i < lastLen || !areAllocationsEqual; i++) {
                if (executedAllocation[i] != _allocations[i]) {
                    areAllocationsEqual = false;
                    break;
                }
            }
        }

        if (areAllocationsEqual && underlyingBalanceInPool() == 0) {
            return;
        }

        IStrategy _strategy;
        uint256 _proposedAllocation;
        uint256 _currentAllocation;
        uint256 _totalAllocation;

        uint256[] memory _allocateFunds = new uint256[](_allocations.length);
        (uint256[] memory currentAllocations, uint256 totalBalance) = _investedBalanceWithAllocations();

        for (uint256 i = 0; i < _allocations.length; i++) {
            _totalAllocation += _allocations[i];
            _proposedAllocation = _allocations[i].mul(totalBalance).div(FULL_ALLOC);

            if (i + 1 > lastLen) {
                _currentAllocation = 0;
            } else {
                _currentAllocation = currentAllocations[i];
            }
            _strategy = IStrategy(underlyingStrategy[i]);
            uint256 investedStrategyBalance = _strategy.investedUnderlyingBalance();
            uint256 allocationDiff;

            if (_proposedAllocation < _currentAllocation) {
                // redeem the diff
                allocationDiff = investedStrategyBalance == 0
                    ?   0
                    :   (_currentAllocation.sub(_proposedAllocation))
                        .mul(FULL_ALLOC)
                        .div(investedStrategyBalance);

                if (allocationDiff > MARGIN_ALLOC) {
                    _strategy.redeem(allocationDiff, FULL_ALLOC, address(this));
                }

            } else if (_proposedAllocation > _currentAllocation) {
                // should invest the diff amount once everything is redeemed
                allocationDiff = investedStrategyBalance == 0
                    ?   FULL_ALLOC
                    :   (_proposedAllocation.sub(_currentAllocation))
                    .mul(FULL_ALLOC)
                    .div(investedStrategyBalance);

                if (allocationDiff > MARGIN_ALLOC) {
                    _allocateFunds[i] = _proposedAllocation.sub(_currentAllocation);
                }
            }
        }

        require(_totalAllocation == FULL_ALLOC, "NOT_FULL_ALLOCATION");

        // invest missing allocations where needed
        for (uint256 i = 0; i < _allocateFunds.length; i++) {
            _proposedAllocation = _allocateFunds[i];

            if (_proposedAllocation <= 0) {
                continue;
            }
            _strategy = IStrategy(underlyingStrategy[i]);

            _invest(_strategy, _proposedAllocation, underlyingBalanceInPool());
            _strategy.rebalance(_underlyingData);
        }
        
        executedAllocation = _allocations;
    }

    function changeController(address _controller) external override onlyOwner {
        controller = _controller;
    }

    /// @notice Get the total balance of the underlying token owned by the pool and its strategies.
    /// @return total underlying balance.
    function investedUnderlyingBalance() public override view returns (uint256 total) {
        if (executedAllocation.length == 0) {
            return underlyingBalanceInPool();
        }

        (,total) = _investedBalanceWithAllocations();
    }

    function _investedBalanceWithAllocations() public view returns (
        uint256[] memory currentAllocations, uint256 total
    ) {

        currentAllocations = new uint256[](executedAllocation.length);

        address strategy;
        for (uint256 i = 0; i < executedAllocation.length; i++) {
            strategy = underlyingStrategy[i];
            require(strategy != address(0), "NO_STRATEGY");
            uint256 invested = IStrategy(strategy).investedUnderlyingBalance();

            currentAllocations[i] = invested;
            total = total.add(invested);
        }

        // add pool balance
        total = total.add(underlyingBalanceInPool());
    }

    /// @notice APR for the current protocol toke
    function getAPR() external override view returns (uint256 avgApr) {
        
        uint256 total;
        uint256 allocatedBalance;
        IStrategy strategy;

        for (uint256 i = 0; i < executedAllocation.length; i++) {
            
            strategy = IStrategy(underlyingStrategy[i]);
            allocatedBalance = strategy.investedUnderlyingBalance();

            if (allocatedBalance == 0) {
                continue;
            }
            total = total.add(allocatedBalance);

            avgApr = avgApr.add(strategy.getAPR().mul(allocatedBalance));
        }
        
        if (total > 0) {
            avgApr = avgApr.div(total);
        }
    }

    /// @notice Get the balance of the underlying token owned by the pool itself.
    /// @return uint256 underlying balance.
    function underlyingBalanceInPool() public view returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }

    /// @notice Redeem the given amount from all the available strategies.
    /// @param  _amount to redeem.
    /// @param  _totalSupply of tokens available for redeem.
    /// @return redeemedTokens tokens redeemed.
    function _redeemInternal(uint256 _amount, uint256 _totalSupply, address _account)
        private returns (uint256 redeemedTokens) {

        address strategy;
        for (uint256 i = 0; i < executedAllocation.length; i++) {
            strategy = underlyingStrategy[i];
            require(strategy != address(0), "NO_STRATEGY");
            uint256 strategyBalance = IStrategy(strategy).investedUnderlyingBalance();
            if (strategyBalance > 0) {
                redeemedTokens = redeemedTokens.add(
                    IStrategy(strategy).redeem(_amount, _totalSupply, _account)
                );
            }
        }

        redeemedTokens += _amount.mul(underlyingBalanceInPool()).div(_totalSupply);
    }

    function _invest(IStrategy _strategy, uint256 _allocation, uint256 _total) internal {
        uint256 availableAmount = _allocation <= _total
            ?   _allocation
            :   _total;
        if (availableAmount > 0) {
            IERC20(underlying).safeTransfer(address(_strategy), availableAmount);
        }
    }
}