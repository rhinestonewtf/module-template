// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount
} from "modulekit/test/utils/biconomy-base/RhinestoneModuleKit.sol";
import { ValidatorTemplate, ERC1271_MAGICVALUE } from "../../src/validators/ValidatorTemplate.sol";

contract ValidatorTemplateTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount instance;
    ValidatorTemplate validatorTemplate;

    function setUp() public {
        // Setup account
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 10 ether);

        // Setup validator
        validatorTemplate = new ValidatorTemplate();

        // Add validator to account
        instance.addValidator(address(validatorTemplate));
    }

    function testSendEth() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        instance.exec4337({
            target: receiver,
            value: value,
            callData: callData,
            signature: signature
        });

        // Validate userOperation
        assertEq(receiver.balance, 10 gwei, "Receiver should have 10 gwei");
    }

    function test1271Signature() public {
        // Create signature
        bytes32 hash = keccak256("signature");
        bytes memory signature = "";

        // Validate signature
        vm.prank(instance.account);
        bytes4 returnValue = validatorTemplate.isValidSignature(hash, signature);

        // Validate signature success
        assertEq(
            returnValue,
            ERC1271_MAGICVALUE, // EIP1271_MAGIC_VALUE
            "Signature should be valid"
        );
    }
}
