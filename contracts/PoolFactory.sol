// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./interfaces/IPool.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/IBaseContract.sol";
import "./interfaces/IStrategy.sol";

import "./Beacon.sol";

/// @title  PoolFactory
/// @notice Creates new pools for underlying tokens.
contract PoolFactory is Beacon, IPoolFactory, IBaseContract {

    mapping(address => address) public override poolAddresses;
    address[] public tokenAddresses;

    /// @notice address of strategies per underlying token/key
    mapping(bytes32 => address) public poolStrategies;

    event PoolProxyDeployed(address proxy);

    /// @notice Creates new pools for underlying token. Only owner.
    /// @param  poolToken  address of the underlying token to crete pool for.
    /// @return address pool address
    function createPool(address poolToken, bytes32 _poolId,
        address _feeAddress, uint256 _fee,
        address _strategy)
    external onlyOwner returns (address) {

        // Check if a pool was already created for the given token.
        require(_strategy != address(0), "ZERO_ADDRESS");
        require(poolToken != address(0), "ZERO_ADDRESS");
        require(poolAddresses[poolToken] == address(0), "ALREADY_CREATED");

        // Deploy a minimal proxy that gets the implementation address from the beacon
        address instance = Clones.cloneDeterministic(implementation(_poolId), _poolId);
        emit PoolProxyDeployed(instance);

        // Check that the contract was created
        require(instance != address(0), "NOT_CREATED");

        // Set pool/token name and symbol
        string memory _name = ERC20(poolToken).name();
        string memory _symbol = "LPT";

        // init the pool; add initial strategies
        IPool(instance).initialize(_name, _symbol, poolToken,
            _feeAddress, _fee,
            _strategy, msg.sender);

        tokenAddresses.push(poolToken);

        // Map created pool with proxy
        poolAddresses[poolToken] = instance;
        return instance;

    }

    /// @notice Creates new strategy for underlying token. Only owner.
    /// @param  _underlying Underlying token address
    /// @param  _strategyId Strategy id
    /// @param  _registry Contract registry
    /// @param  _data call data
    /// @return address strategy address
    function createStrategy(address _underlying, bytes32 _strategyId, address _registry,
        address _controller, bytes calldata _data)
    external onlyOwner returns (address) {

        require(_registry != address(0), "ZERO_ADDRESS");
        require(_underlying != address(0), "ZERO_ADDRESS");

        bytes32 _key = keccak256(abi.encodePacked(_underlying, _strategyId));
        require(poolStrategies[_key] == address(0), "ALREADY_CREATED");

        // Deploy a minimal proxy that gets the implementation address from the beacon
        address instance = Clones.cloneDeterministic(implementation(_strategyId), _strategyId);

        // Check that the contract was created
        require(instance != address(0), "NOT_CREATED");

        // init the strategy
        IStrategy(instance).initialize(_underlying, _registry, _controller, msg.sender, _data);
        poolStrategies[_key] = instance;

        return instance;
    }

    /// @notice Pool count
    /// @return uint256 count
    function getTokenAddresses() public view returns (uint256) {
        return tokenAddresses.length;
    }

    /// @notice Contract name
    /// @return bytes32 name
    function getName() override external view returns (bytes32) {
        return "PoolFactory";
    }

    function getStrategyAddress(bytes32 _strategyId) external view returns (address) {
        address master = implementation(_strategyId);
        require(master != address(0), "master must be set");
        return Clones.predictDeterministicAddress(master, _strategyId);
    }

    // solhint-disable-next-line
    receive() external payable {}

}
