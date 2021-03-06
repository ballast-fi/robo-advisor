// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IStrategy {

    function initialize(
        address _underlying, address _registry, address _controller,
        address _owner, bytes memory _data
    ) external;

    function redeem(uint256 _redeemAmount, uint256 _totalSupply, address _account) external returns (uint256);

    function rebalance(bytes memory _data) external;

    function changeController(address _controller) external;

    function getAPR() external view returns (uint256);

    function investedUnderlyingBalance() external view returns (uint256);

    function underlying() external view returns (address);
}