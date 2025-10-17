// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ICreateX
 * @notice Minimal interface for CreateX contract
 * @dev This is a placeholder to satisfy imports. CreateX functionality not used in V2 pools.
 */
interface ICreateX {
    function computeCreate3Address(bytes32 salt, address deployer) external view returns (address);
}


