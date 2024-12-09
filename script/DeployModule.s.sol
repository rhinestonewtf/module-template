// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/registry/RegistryDeployer.sol";

// Import modules here
import { ValidatorTemplate } from "src/ValidatorTemplate.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        // Setup module bytecode, deploy params, and data
        bytes memory bytecode = type(ValidatorTemplate).creationCode;
        bytes memory resolverContext = "";
        bytes memory metadata = "";

        // Get private key for deployment
        vm.startBroadcast(vm.envUint("PK"));

        // Deploy module
        address module = deployModule({
            initCode: bytecode,
            resolverContext: resolverContext,
            salt: bytes32(0),
            metadata: metadata
        });

        // Stop broadcast and log module address
        vm.stopBroadcast();
        console.log("Deploying module at: %s", module);
    }
}
