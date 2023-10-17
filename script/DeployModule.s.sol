// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {ModuleDeployer} from "./ModuleDeployer.sol";

// Import modules here
import {SimpleValidator} from "../src/validators/SimpleValidator.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, ModuleDeployer {
    function run() public {
        bytes memory bytecode = type(SimpleValidator).creationCode;
        vm.startBroadcast(vm.envUint("PK"));

        address moduleAddr = deployModule({code: bytecode, deployParams: bytes(""), salt: 0, data: bytes("")});

        vm.stopBroadcast();
        console.log("Module deployed at: %s", moduleAddr);
         console.log("See module details at: https://dev.rhinestone.wtf/%s", moduleAddr);
    }
}
