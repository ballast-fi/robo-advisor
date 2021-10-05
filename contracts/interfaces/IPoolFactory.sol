// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IPoolFactory {

    function poolAddresses(address underlying) external view returns (address pool);

}