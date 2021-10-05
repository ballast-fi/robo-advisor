// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IPool {

    function initialize(
        string calldata name, string calldata symbol, address token,
        address _feeAddress, uint256 _fee,
        address _strategy, address _owner
    ) external;

    function underlyingStrategy() external view returns (address);

}