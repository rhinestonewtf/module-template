// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ExecutorBase } from "modulekit/modulekit/ExecutorBase.sol";
import { IExecutorManager, ExecutorAction, ModuleExecLib } from "modulekit/modulekit/IExecutor.sol";

contract ExecutorTemplate is ExecutorBase {
    using ModuleExecLib for IExecutorManager;

    /**
     * @notice A function that executes an action.
     * @param account address of the account
     * @param data bytes data to be used for execution
     */
    function executeAction(address account, bytes memory data) external {
        // Get the manager from data
        (IExecutorManager manager) = abi.decode(data, (IExecutorManager));

        // Create the actions to be executed
        ExecutorAction[] memory actions = new ExecutorAction[](2);
        actions[0] = ExecutorAction({ to: payable(msg.sender), value: 1 wei, data: "" });

        // Execute the actions
        manager.exec(account, actions);
    }

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
    function metadataProvider()
        external
        view
        override
        returns (uint256 providerType, bytes memory location)
    {
        providerType = 0;
        location = "";
    }

    /**
     * @notice A function that indicates if the executor requires root access to a Safe.
     * @return requiresRootAccess True if root access is required, false otherwise.
     */
    function requiresRootAccess() external view override returns (bool requiresRootAccess) {
        requiresRootAccess = false;
    }
}
