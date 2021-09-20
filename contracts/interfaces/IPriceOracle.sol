// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceOracle {
    function getPriceUSD(address _asset) external view returns (uint256 price);
    function getPriceETH(address _asset) external view returns (uint256 price);
    function getPriceToken(address _asset, address _token) external view returns (uint256 price);
}