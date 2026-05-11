// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/registry/RegistryDeployer.sol";

// Import modules here
import { ExecutorTemplate } from "src/ExecutorTemplate.sol";
import { ValidatorTemplate } from "src/ValidatorTemplate.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        bytes memory resolverContext = "";
        bytes memory metadata = "";

        vm.startBroadcast(vm.envUint("PK"));

        // Deploy Executor (Aave actions)
        address executorModule = deployModule({
            initCode: type(ExecutorTemplate).creationCode,
            resolverContext: resolverContext,
            salt: bytes32(uint256(1)),
            metadata: metadata
        });

        // Deploy Validator (template)
        address validatorModule = deployModule({
            initCode: type(ValidatorTemplate).creationCode,
            resolverContext: resolverContext,
            salt: bytes32(uint256(2)),
            metadata: metadata
        });

        vm.stopBroadcast();

        console.log("ExecutorTemplate module: %s", executorModule);
        console.log("ValidatorTemplate module: %s", validatorModule);
    }
}
