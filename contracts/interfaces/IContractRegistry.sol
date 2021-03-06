// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./IPoolFactory.sol";
import "./IPriceOracle.sol";

interface IContractRegistry {

    function getAddress(bytes32 name) external view returns (address);

    function requireAndGetAddress(bytes32 name) external view returns (address);

    function poolFactory() external view returns (IPoolFactory);

    function priceOracle() external view returns (IPriceOracle);
}
