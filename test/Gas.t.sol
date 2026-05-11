// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, AccountInstance} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {ExecutorTemplate} from "src/ExecutorTemplate.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
        external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);
    function getUserAccountData(address user)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256);
}

/// @notice Gas comparison harness: EOA path vs ERC-7579 smart account paths.
/// Reports per-workflow gas costs to stdout. Run with:
///   forge test --match-contract GasTest -vv
contract GasTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;

    AccountInstance internal instance;
    ExecutorTemplate internal executor;

    address constant POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 constant USDC_DECIMALS = 6;
    uint256 constant TX_BASE = 21_000;

    address eoa = address(0xBEEF);

    uint256 collateral = 10_000 * 10 ** USDC_DECIMALS;
    uint256 borrowAmt = 0.5 ether;

    function setUp() public {
        init();
        executor = new ExecutorTemplate();
        instance = makeAccountInstance("GasTest");
        vm.deal(address(instance.account), 1 ether);
        vm.deal(eoa, 1 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: abi.encode(POOL, WETH, USDC)
        });
    }

    /*//////////////////////////////////////////////////////////////
                              EOA SCENARIOS
    //////////////////////////////////////////////////////////////*/

    /// @dev Measures pure execution gas of AAVE calls from an EOA, then adds
    /// TX_BASE per logical transaction (since each EOA call is its own tx).
    function testGas_EOA_Supply() public {
        deal(USDC, eoa, collateral);
        vm.startPrank(eoa);
        uint256 g = gasleft();
        IERC20(USDC).approve(POOL, collateral);
        IPool(POOL).supply(USDC, collateral, eoa, 0);
        uint256 used = g - gasleft();
        vm.stopPrank();
        uint256 total = used + 2 * TX_BASE;
        console.log("EOA_Supply:", total);
    }

    function testGas_EOA_Supply_Borrow() public {
        deal(USDC, eoa, collateral);
        vm.startPrank(eoa);
        uint256 g = gasleft();
        IERC20(USDC).approve(POOL, collateral);
        IPool(POOL).supply(USDC, collateral, eoa, 0);
        IPool(POOL).borrow(WETH, borrowAmt, 2, 0, eoa);
        uint256 used = g - gasleft();
        vm.stopPrank();
        uint256 total = used + 3 * TX_BASE;
        console.log("EOA_Supply_Borrow:", total);
    }

    function testGas_EOA_Supply_Borrow_Repay() public {
        deal(USDC, eoa, collateral);
        vm.startPrank(eoa);
        uint256 g = gasleft();
        IERC20(USDC).approve(POOL, collateral);
        IPool(POOL).supply(USDC, collateral, eoa, 0);
        IPool(POOL).borrow(WETH, borrowAmt, 2, 0, eoa);
        IERC20(WETH).approve(POOL, borrowAmt);
        IPool(POOL).repay(WETH, borrowAmt, 2, eoa);
        uint256 used = g - gasleft();
        vm.stopPrank();
        uint256 total = used + 5 * TX_BASE;
        console.log("EOA_Supply_Borrow_Repay:", total);
    }

    function testGas_EOA_FullCycle() public {
        deal(USDC, eoa, collateral);
        vm.startPrank(eoa);
        uint256 g = gasleft();
        IERC20(USDC).approve(POOL, collateral);
        IPool(POOL).supply(USDC, collateral, eoa, 0);
        IPool(POOL).borrow(WETH, borrowAmt, 2, 0, eoa);
        IERC20(WETH).approve(POOL, borrowAmt);
        IPool(POOL).repay(WETH, borrowAmt, 2, eoa);
        IPool(POOL).withdraw(USDC, collateral / 2, eoa);
        uint256 used = g - gasleft();
        vm.stopPrank();
        uint256 total = used + 6 * TX_BASE;
        console.log("EOA_FullCycle:", total);
    }

    /*//////////////////////////////////////////////////////////////
                  SMART ACCOUNT - NATIVE 7579 BATCH
                  (no executor module: raw approve+pool calls)
    //////////////////////////////////////////////////////////////*/

    function _execBatch(Execution[] memory execs) internal returns (uint256) {
        uint256 g = gasleft();
        instance.getExecOps(execs, address(instance.defaultValidator)).signDefault().execUserOps();
        return (g - gasleft()) + TX_BASE;
    }

    function _exec(address target, bytes memory cd) internal returns (uint256) {
        uint256 g = gasleft();
        instance.exec({target: target, value: 0, callData: cd});
        return (g - gasleft()) + TX_BASE;
    }

    function testGas_Native_Supply() public {
        deal(USDC, address(instance.account), collateral);
        Execution[] memory execs = new Execution[](2);
        execs[0] = Execution({
            target: USDC,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (POOL, collateral))
        });
        execs[1] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(IPool.supply, (USDC, collateral, address(instance.account), 0))
        });
        console.log("Native_Supply:", _execBatch(execs));
    }

    function testGas_Native_Supply_Borrow() public {
        deal(USDC, address(instance.account), collateral);
        Execution[] memory execs = new Execution[](3);
        execs[0] = Execution({
            target: USDC,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (POOL, collateral))
        });
        execs[1] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(IPool.supply, (USDC, collateral, address(instance.account), 0))
        });
        execs[2] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(
                IPool.borrow, (WETH, borrowAmt, 2, 0, address(instance.account))
            )
        });
        console.log("Native_Supply_Borrow:", _execBatch(execs));
    }

    function testGas_Native_Supply_Borrow_Repay() public {
        deal(USDC, address(instance.account), collateral);
        Execution[] memory execs = new Execution[](5);
        execs[0] = Execution({
            target: USDC,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (POOL, collateral))
        });
        execs[1] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(IPool.supply, (USDC, collateral, address(instance.account), 0))
        });
        execs[2] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(
                IPool.borrow, (WETH, borrowAmt, 2, 0, address(instance.account))
            )
        });
        execs[3] = Execution({
            target: WETH,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (POOL, borrowAmt))
        });
        execs[4] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(
                IPool.repay, (WETH, borrowAmt, 2, address(instance.account))
            )
        });
        console.log("Native_Supply_Borrow_Repay:", _execBatch(execs));
    }

    function testGas_Native_FullCycle() public {
        deal(USDC, address(instance.account), collateral);
        Execution[] memory execs = new Execution[](6);
        execs[0] = Execution({
            target: USDC,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (POOL, collateral))
        });
        execs[1] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(IPool.supply, (USDC, collateral, address(instance.account), 0))
        });
        execs[2] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(
                IPool.borrow, (WETH, borrowAmt, 2, 0, address(instance.account))
            )
        });
        execs[3] = Execution({
            target: WETH,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (POOL, borrowAmt))
        });
        execs[4] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(
                IPool.repay, (WETH, borrowAmt, 2, address(instance.account))
            )
        });
        execs[5] = Execution({
            target: POOL,
            value: 0,
            callData: abi.encodeCall(
                IPool.withdraw, (USDC, collateral / 2, address(instance.account))
            )
        });
        console.log("Native_FullCycle:", _execBatch(execs));
    }

    /*//////////////////////////////////////////////////////////////
                  SMART ACCOUNT - WITH EXECUTOR MODULE
                  (this thesis' contribution)
    //////////////////////////////////////////////////////////////*/

    function _moduleCall(address asset, uint256 amount, uint8 action)
        internal
        view
        returns (bytes memory)
    {
        bytes memory data = abi.encode(asset, amount, address(instance.account), uint16(0), action);
        return abi.encodeWithSelector(ExecutorTemplate.execute.selector, data);
    }

    function testGas_Module_Supply() public {
        deal(USDC, address(instance.account), collateral);
        console.log("Module_Supply:", _exec(address(executor), _moduleCall(USDC, collateral, 0)));
    }

    function testGas_Module_Supply_Borrow() public {
        deal(USDC, address(instance.account), collateral);
        Execution[] memory execs = new Execution[](2);
        execs[0] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(USDC, collateral, 0)
        });
        execs[1] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(WETH, borrowAmt, 2)
        });
        console.log("Module_Supply_Borrow:", _execBatch(execs));
    }

    function testGas_Module_Supply_Borrow_Repay() public {
        deal(USDC, address(instance.account), collateral);
        Execution[] memory execs = new Execution[](3);
        execs[0] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(USDC, collateral, 0)
        });
        execs[1] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(WETH, borrowAmt, 2)
        });
        execs[2] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(WETH, borrowAmt, 3)
        });
        console.log("Module_Supply_Borrow_Repay:", _execBatch(execs));
    }

    function testGas_Module_FullCycle() public {
        deal(USDC, address(instance.account), collateral);
        Execution[] memory execs = new Execution[](4);
        execs[0] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(USDC, collateral, 0)
        });
        execs[1] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(WETH, borrowAmt, 2)
        });
        execs[2] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(WETH, borrowAmt, 3)
        });
        execs[3] = Execution({
            target: address(executor),
            value: 0,
            callData: _moduleCall(USDC, collateral / 2, 1)
        });
        console.log("Module_FullCycle:", _execBatch(execs));
    }
}
