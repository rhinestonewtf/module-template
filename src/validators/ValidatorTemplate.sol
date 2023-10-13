// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ValidatorBase, UserOperation, VALIDATION_SUCCESS, ERC1271_MAGICVALUE
} from "modulekit/modulekit/ValidatorBase.sol";

contract ValidatorTemplate is ValidatorBase {
    /**
     * @dev validates userOperation
     * @param userOp User Operation to be validated.
     * @param userOpHash Hash of the User Operation to be validated.
     * @return sigValidationResult 0 if signature is valid, 1 otherwise.
     */
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash)
        external
        view
        override
        returns (uint256)
    {
        return VALIDATION_SUCCESS;
    }

    /**
     * @dev validates a 1271 signature request
     * @param signedDataHash Hash of the signed data.
     * @param moduleSignature Signature to be validated.
     * @return eip1271Result 0x1626ba7e if signature is valid, 0xffffffff otherwise.
     */
    function isValidSignature(bytes32 signedDataHash, bytes memory moduleSignature)
        public
        view
        override
        returns (bytes4)
    {
        return ERC1271_MAGICVALUE;
    }
}
