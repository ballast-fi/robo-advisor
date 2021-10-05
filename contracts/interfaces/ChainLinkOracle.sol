// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface ChainLinkOracle {
    function latestAnswer() external view returns (uint256);
}