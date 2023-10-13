// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ExecutorBase} from "modulekit/modulekit/ExecutorBase.sol";

contract ExecutorTemplate is ExecutorBase {
    /**
     * @notice A funtion that returns name of the executor
     * @return name string name of the executor
     */
    function name() external view override returns (string memory name) {
        name = "ExecutorTemplate";
    }

    /**
     * @notice A funtion that returns version of the executor
     * @return version string version of the executor
     */
    function version() external view override returns (string memory version) {
        version = "0.0.1";
    }

    /**
     * @notice A funtion that returns version of the executor.
     * @return providerType uint256 Type of metadata provider
     * @return location bytes
     */
    function metadataProvider() external view override returns (uint256 providerType, bytes memory location) {}

    /**
     * @notice A function that indicates if the executor requires root access to a Safe.
     * @return requiresRootAccess True if root access is required, false otherwise.
     */
    function requiresRootAccess() external view override returns (bool requiresRootAccess) {
        requiresRootAccess = false;
    }

    /**
     * @notice Query if a contract implements an interface
     * @param interfaceID The interface identifier, as specified in ERC-165
     * @dev Interface identification is specified in ERC-165. This function
     * uses less than 30,000 gas.
     * @return `true` if the contract implements `interfaceID` and
     * `interfaceID` is not 0xffffffff, `false` otherwise
     */
    function supportsInterface(bytes4 interfaceID) external view returns (bool) {}
}
