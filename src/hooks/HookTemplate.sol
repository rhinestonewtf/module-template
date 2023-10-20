// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { HookBase, ExecutorTransaction } from "modulekit/modulekit/HookBase.sol";

contract HookTemplate is HookBase {
    function preCheck(
        address account,
        ExecutorTransaction calldata transaction,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        override
        returns (bytes memory preCheckData)
    {
        return "";
    }

    function preCheckRootAccess(
        address account,
        ExecutorTransaction calldata rootAccess,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        override
        returns (bytes memory preCheckData)
    {
        return "";
    }

    function postCheck(
        address account,
        bool success,
        bytes calldata preCheckData
    )
        external
        override
    { }
}
