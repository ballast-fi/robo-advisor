// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ChainLinkOracle {
    function latestAnswer() external view returns (uint256);
}