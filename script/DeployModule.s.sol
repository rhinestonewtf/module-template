// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/modulekit/deployment/RegistryDeployer.sol";

// Import modules here
import { ValidatorTemplate } from "../src/validators/ValidatorTemplate.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        // Setup module bytecode, deploy params, and data
        bytes memory bytecode = type(ValidatorTemplate).creationCode;
        bytes memory deployParams = "";
        bytes memory data = "";

        // Get private key for deployment
        vm.startBroadcast(vm.envUint("PK"));

        // Deploy module
        address module = deployModule({
            code: bytecode,
            deployParams: deployParams,
            salt: bytes32(0),
            data: data
        });

        // Stop broadcast and log module address
        vm.stopBroadcast();
        console.log("Module deployed at: %s", module);
    }
}
