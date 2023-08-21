// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {RhinestoneModuleKit, RhinestoneModuleKitLib, RhinestoneAccount} from "@rhinestone/modulekit/test/utils/safe-base/RhinestoneModuleKit.sol";
import {SimpleValidator} from "../../../src/validators/SimpleValidator.sol";

contract SimpleValidatorTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount;
    using ECDSA for bytes32;

    RhinestoneAccount instance;
    SimpleValidator simpleValidator;

    function setUp() public {
        // Setup account
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 10 ether);

        // Setup validator
        simpleValidator = new SimpleValidator();
        (address owner, ) = makeAddrAndKey("owner");
        simpleValidator.setOwner(address(instance.account), owner);

        // Add validator to account
        instance.addValidator(address(simpleValidator));
    }

    function testSendEth() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        uint8 operation = 0;

        // Create signature
        (, uint256 key) = makeAddrAndKey("owner");
        bytes32 hash = instance.getUserOpHash({
            target: receiver,
            value: value,
            callData: callData,
            operation: operation
        });
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            key,
            hash.toEthSignedMessageHash()
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        // Create userOperation
        instance.exec4337({
            target: receiver,
            value: value,
            callData: callData,
            operation: operation,
            signature: signature
        });

        // Validate userOperation
        assertEq(receiver.balance, 10 gwei, "Receiver should have 10 gwei");
    }

    function testRecoverValidator() public {
        address newOwner = makeAddr("newOwner");
        // Recover validator
        vm.prank(instance.account);
        simpleValidator.recoverValidator(
            address(0),
            bytes(""),
            abi.encode(newOwner)
        );

        // Validate recovery success
        assertEq(
            simpleValidator.owners(address(instance.account)),
            newOwner,
            "Validator should be recovered"
        );
    }

    function test1271Signature() public {
        // Create signature
        (address owner, uint256 key) = makeAddrAndKey("owner");
        bytes32 hash = keccak256("Test sinature");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            key,
            hash.toEthSignedMessageHash()
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        // Validate signature
        vm.prank(instance.account);
        bytes4 returnValue = simpleValidator.isValidSignature(hash, signature);

        // Validate signature success
        assertEq(
            returnValue,
            bytes4(0x1626ba7e), // EIP1271_MAGIC_VALUE
            "Signature should be valid"
        );
    }
}
