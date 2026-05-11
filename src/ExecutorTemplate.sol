// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC7579ExecutorBase} from "modulekit/Modules.sol";
import {IERC7579Account} from "modulekit/Accounts.sol";
import {ModeLib} from "modulekit/accounts/common/lib/ModeLib.sol";

library SmartAAVE {
    enum ActionAAVE {
        SUPPLY,
        WITHDRAW,
        BORROW,
        REPAY,
        VALID
    }
}

interface IPool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function withdraw(address asset, uint256 amount, address to) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract ExecutorTemplate is ERC7579ExecutorBase {
    //IPool pool = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    address public pool;
    address public asset0;
    address public asset1;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     *
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        (address _pool, address _asset0, address _asset1) = abi.decode(
            data,
            (address, address, address)
        );
        pool = _pool;
        asset0 = _asset0;
        asset1 = _asset1;
    }

    /**
     * De-initialize the module with the given data
     *
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {}

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        smartAccount;
        return pool != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * ERC-7579 does not define any specific interface for executors, so the
     * executor can implement any logic that is required for the specific usecase.
     */

    /**
     * Execute the given data
     * @dev This is an example function that can be used to execute arbitrary data
     * @dev This function is not part of the ERC-7579 standard
     *
     * @param data The data to execute
     */
    function execute(bytes calldata data) external {
        (
            address asset,
            uint256 amount,
            address onBehalfOf,
            ,
            SmartAAVE.ActionAAVE action
        ) = abi.decode(
                data,
                (address, uint256, address, uint16, SmartAAVE.ActionAAVE)
            );
        require(action < SmartAAVE.ActionAAVE.VALID, "action not valid");
        if (action == SmartAAVE.ActionAAVE.SUPPLY) {
            _execute(asset, 0, abi.encodeCall(IERC20.approve, (pool, amount)));
            _execute(pool, 0, abi.encodeCall(IPool.supply, (asset, amount, onBehalfOf, 0)));
        }
        if (action == SmartAAVE.ActionAAVE.WITHDRAW) {
            _execute(pool, 0, abi.encodeCall(IPool.withdraw, (asset, amount, onBehalfOf)));
        }
        if (action == SmartAAVE.ActionAAVE.BORROW) {
            _execute(pool, 0, abi.encodeCall(IPool.borrow, (asset, amount, 2, 0, onBehalfOf)));
        }
        if (action == SmartAAVE.ActionAAVE.REPAY) {
            _execute(asset, 0, abi.encodeCall(IERC20.approve, (pool, amount)));
            _execute(pool, 0, abi.encodeCall(IPool.repay, (asset, amount, 2, onBehalfOf)));
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     *
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "ExecutorTemplate";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /**
     * Check if the module is of a certain type
     *
     * @param typeID The type ID to check
     *
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(
        uint256 typeID
    ) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
