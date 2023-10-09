// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "forge-std/interfaces/IERC165.sol";
import "forge-std/console2.sol";

// Struct that represents an attestation.
struct AttestationRecord {
    bytes32 schemaUID; // The unique identifier of the schema.
    address subject; // The recipient of the attestation i.e. module
    address attester; // The attester/sender of the attestation.
    uint48 time; // The time when the attestation was created (Unix timestamp).
    uint48 expirationTime; // The time when the attestation expires (Unix timestamp).
    uint48 revocationTime; // The time when the attestation was revoked (Unix timestamp).
    address dataPointer; // SSTORE2 pointer to the attestation data.
}

// Struct that represents Module artefact.
struct ModuleRecord {
    bytes32 resolverUID; // The unique identifier of the resolver.
    address implementation; // The deployed contract address
    address sender; // The address of the sender who deployed the contract
    bytes data; // Additional data related to the contract deployment
}

interface IResolver is IERC165 {
    /**
     * @dev Returns whether the resolver supports ETH transfers.
     */
    function isPayable() external pure returns (bool);

    /**
     * @dev Processes an attestation and verifies whether it's valid.
     *
     * @param attestation The new attestation.
     *
     * @return Whether the attestation is valid.
     */
    function attest(AttestationRecord calldata attestation) external payable returns (bool);

    /**
     * @dev Processes a Module Registration
     *
     * @param module Module registration artefact
     *
     * @return Whether the registration is valid
     */
    function moduleRegistration(ModuleRecord calldata module) external payable returns (bool);

    /**
     * @dev Processes multiple attestations and verifies whether they are valid.
     *
     * @param attestations The new attestations.
     * @param values Explicit ETH amounts which were sent with each attestation.
     *
     * @return Whether all the attestations are valid.
     */
    function multiAttest(AttestationRecord[] calldata attestations, uint256[] calldata values)
        external
        payable
        returns (bool);

    /**
     * @dev Processes an attestation revocation and verifies if it can be revoked.
     *
     * @param attestation The existing attestation to be revoked.
     *
     * @return Whether the attestation can be revoked.
     */
    function revoke(AttestationRecord calldata attestation) external payable returns (bool);

    /**
     * @dev Processes revocation of multiple attestation and verifies they can be revoked.
     *
     * @param attestations The existing attestations to be revoked.
     * @param values Explicit ETH amounts which were sent with each revocation.
     *
     * @return Whether the attestations can be revoked.
     */
    function multiRevoke(AttestationRecord[] calldata attestations, uint256[] calldata values)
        external
        payable
        returns (bool);
}

struct ResolverRecord {
    IResolver resolver; // Optional schema resolver.
    address schemaOwner; // The address of the account used to register the schema.
}

interface IRegistry {
    function deploy(
        bytes calldata code,
        bytes calldata deployParams,
        bytes32 salt,
        bytes calldata data,
        bytes32 resolverUID
    ) external payable returns (address moduleAddr);

    function deployC3(
        bytes calldata code,
        bytes calldata deployParams,
        bytes32 salt,
        bytes calldata data,
        bytes32 resolverUID
    ) external payable returns (address moduleAddr);

    function deployViaFactory(address factory, bytes calldata callOnFactory, bytes calldata data, bytes32 resolverUID)
        external
        payable
        returns (address moduleAddr);

    function registerResolver(IResolver _resolver) external returns (bytes32);

    function getResolver(bytes32 uid) external view returns (ResolverRecord memory);
}

abstract contract ResolverBase is IResolver {
    error InsufficientValue();
    error NotPayable();
    error InvalidRS();
    error AccessDenied();

    // The version of the contract.
    string public constant VERSION = "0.1";

    // The global Rhinestone Registry contract.
    address internal immutable _rs;

    /**
     * @dev Creates a new resolver.
     *
     * @param rs The address of the global RS contract.
     */
    constructor(address rs) {
        if (rs == address(0)) {
            revert InvalidRS();
        }
        _rs = rs;
    }

    /**
     * @dev Ensures that only the RS contract can make this call.
     */
    modifier onlyRS() {
        _onlyRSRegistry();
        _;
    }

    /**
     * @inheritdoc IResolver
     */
    function isPayable() public pure virtual returns (bool) {
        return false;
    }

    /**
     * @dev ETH callback.
     */
    receive() external payable virtual {
        if (!isPayable()) {
            revert NotPayable();
        }
    }

    /**
     * @inheritdoc IResolver
     */
    function attest(AttestationRecord calldata attestation) external payable onlyRS returns (bool) {
        return onAttest(attestation, msg.value);
    }

    /**
     * @inheritdoc IResolver
     */
    function moduleRegistration(ModuleRecord calldata module) external payable onlyRS returns (bool) {
        return onModuleRegistration(module, msg.value);
    }

    /**
     * @inheritdoc IResolver
     */

    function multiAttest(AttestationRecord[] calldata attestations, uint256[] calldata values)
        external
        payable
        onlyRS
        returns (bool)
    {
        uint256 length = attestations.length;

        // We are keeping track of the remaining ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 remainingValue = msg.value;

        for (uint256 i; i < length; i++) {
            // Ensure that the attester/revoker doesn't try to spend more than available.
            uint256 value = values[i];
            if (value > remainingValue) {
                revert InsufficientValue();
            }

            // Forward the attestation to the underlying resolver and revert in case it isn't approved.
            if (!onAttest(attestations[i], value)) {
                return false;
            }

            unchecked {
                // Subtract the ETH amount, that was provided to this attestation, from the global remaining ETH amount.
                remainingValue -= value;
            }
        }

        return true;
    }

    /**
     * @inheritdoc IResolver
     */
    function revoke(AttestationRecord calldata attestation) external payable onlyRS returns (bool) {
        return onRevoke(attestation, msg.value);
    }

    /**
     * @inheritdoc IResolver
     */
    function multiRevoke(AttestationRecord[] calldata attestations, uint256[] calldata values)
        external
        payable
        onlyRS
        returns (bool)
    {
        uint256 length = attestations.length;

        // We are keeping track of the remaining ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 remainingValue = msg.value;

        for (uint256 i; i < length; i++) {
            // Ensure that the attester/revoker doesn't try to spend more than available.
            uint256 value = values[i];
            if (value > remainingValue) {
                revert InsufficientValue();
            }

            // Forward the revocation to the underlying resolver and revert in case it isn't approved.
            if (!onRevoke(attestations[i], value)) {
                return false;
            }

            unchecked {
                // Subtract the ETH amount, that was provided to this attestation, from the global remaining ETH amount.
                remainingValue -= value;
            }
        }

        return true;
    }

    /**
     * @dev A resolver callback that should be implemented by child contracts.
     *
     * @param attestation The new attestation.
     * @param value An explicit ETH amount that was sent to the resolver. Please note that this value is verified in
     * both attest() and multiAttest() callbacks RS-only callbacks and that in case of multi attestations, it'll
     * usually hold that msg.value != value, since msg.value aggregated the sent ETH amounts for all the attestations
     * in the batch.
     *
     * @return Whether the attestation is valid.
     */
    function onAttest(AttestationRecord calldata attestation, uint256 value) internal virtual returns (bool);

    /**
     * @dev Processes an attestation revocation and verifies if it can be revoked.
     *
     * @param attestation The existing attestation to be revoked.
     * @param value An explicit ETH amount that was sent to the resolver. Please note that this value is verified in
     * both revoke() and multiRevoke() callbacks RS-only callbacks and that in case of multi attestations, it'll
     * usually hold that msg.value != value, since msg.value aggregated the sent ETH amounts for all the attestations
     * in the batch.
     *
     * @return Whether the attestation can be revoked.
     */
    function onRevoke(AttestationRecord calldata attestation, uint256 value) internal virtual returns (bool);

    function onModuleRegistration(ModuleRecord calldata module, uint256 value) internal virtual returns (bool);

    /**
     * @dev Ensures that only the RS contract can make this call.
     */
    function _onlyRSRegistry() private view {
        if (msg.sender != _rs) {
            revert AccessDenied();
        }
    }

    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return interfaceID == this.supportsInterface.selector || interfaceID == this.isPayable.selector
            || interfaceID == this.attest.selector || interfaceID == this.moduleRegistration.selector
            || interfaceID == this.multiAttest.selector || interfaceID == this.revoke.selector
            || interfaceID == this.multiRevoke.selector;
    }
}

contract DebugResolver is ResolverBase {
    constructor(address rs) ResolverBase(rs) {}

    function onAttest(AttestationRecord calldata attestation, uint256 /*value*/ )
        internal
        view
        override
        returns (bool)
    {
        return true;
    }

    function onRevoke(AttestationRecord calldata, /*attestation*/ uint256 /*value*/ )
        internal
        pure
        override
        returns (bool)
    {
        return true;
    }

    function onModuleRegistration(ModuleRecord calldata module, uint256 value) internal override returns (bool) {
        return true;
    }
}

contract ModuleDeployer {
    IRegistry immutable registry = IRegistry(0xafa554B1edae842533A041C16BAf57F61fF909Ee);

    function deployModule(bytes memory code, bytes memory deployParams, bytes32 salt, bytes memory data)
        public
        returns (address moduleAddr)
    {
        bytes32 resolverUID = getResolver();
        moduleAddr = registry.deploy(code, deployParams, salt, data, resolverUID);
    }

    function deployModuleCreate3(bytes memory code, bytes memory deployParams, bytes32 salt, bytes memory data)
        public
        returns (address moduleAddr)
    {
        bytes32 resolverUID = getResolver();
        moduleAddr = registry.deployC3(code, deployParams, salt, data, resolverUID);
    }

    function deployModuleViaFactory(address factory, bytes memory callOnFactory, bytes memory data)
        public
        returns (address moduleAddr)
    {
        bytes32 resolverUID = getResolver();
        moduleAddr = registry.deployViaFactory(factory, callOnFactory, data, resolverUID);
    }

    function getResolver() public returns (bytes32 resolverUID) {
        resolverUID = 0x984f176bc8a8b71d1a35736c5a892be396a01ba80b290a3394d0089b891dcf46;
        ResolverRecord memory resolver = registry.getResolver(resolverUID);
        if (resolver.schemaOwner == address(0)) {
            resolverUID = registerResolver(address(0));
        }
    }

    function registerResolver(address resolver) public returns (bytes32) {
        if (resolver == address(0)) {
            address debugResolver = 0x9C49430a0f240B45f7f0ecc0AcF434E11C5878FF;
            bytes32 _debugResolverCode;
            assembly {
                _debugResolverCode := extcodehash(debugResolver)
            }
            if (_debugResolverCode == bytes32(0)) {
                DebugResolver newDebugResolver = new DebugResolver{salt:0}(address(registry));
                debugResolver = address(newDebugResolver);
            }
            return registry.registerResolver(IResolver(address(debugResolver)));
        } else {
            return registry.registerResolver(IResolver(resolver));
        }
    }
}
