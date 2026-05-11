// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, AccountInstance} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {ExecutorTemplate} from "src/ExecutorTemplate.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
}

interface IPool {
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

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
    function getSourceOfAsset(address asset) external view returns (address);
}

interface IPoolAddressesProvider {
    function getPriceOracle() external view returns (address);
}

contract ExecutorTemplateTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;

    // account and modules
    AccountInstance internal instance;
    ExecutorTemplate internal executor;
    address pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    uint256 constant USDC_DECIMALS = 6;

    function setUp() public {
        init();

        // Create the executor
        executor = new ExecutorTemplate();
        vm.label(address(executor), "ExecutorTemplate");

        // Create the account and install the executor
        instance = makeAccountInstance("ExecutorTemplate");
        vm.deal(address(instance.account), 10 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: abi.encode(pool, WETH, USDC)
        });
    }

    function testOnInstall() public view {
        assertEq(executor.pool(), pool);
        assertEq(executor.asset0(), WETH);
        assertEq(executor.asset1(), USDC);
    }

    function testExecSupply() public {
        deal(WETH, address(instance.account), 10 ether);
        supply();
        assertEq(IERC20(WETH).balanceOf(address(instance.account)), 0);
    }

    function testExecWithdrawSuccess() public {
        deal(WETH, address(instance.account), 10 ether);
        supply();   
        bytes memory supplyData = abi.encode(
            WETH,
            10 ether,
            address(instance.account),
            0,
            1
        );
        instance.exec({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(
                ExecutorTemplate.execute.selector,
                supplyData
            )
        });
        assertGt(IERC20(WETH).balanceOf(address(instance.account)), 10);
    }

    function supply() public {
        bytes memory supplyData = abi.encode(
            WETH,
            10 ether,
            address(instance.account),
            0,
            0
        );
        instance.exec({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(
                ExecutorTemplate.execute.selector,
                supplyData
            )
        });
    }

    function supplyCollateral(uint256 amount) internal {
        bytes memory data = abi.encode(USDC, amount, address(instance.account), 0, 0);
        instance.exec({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(ExecutorTemplate.execute.selector, data)
        });
    }

    function borrow(uint256 amount) internal {
        bytes memory data = abi.encode(WETH, amount, address(instance.account), 0, 2);
        instance.exec({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(ExecutorTemplate.execute.selector, data)
        });
    }

    function repay(uint256 amount) internal {
        bytes memory data = abi.encode(WETH, amount, address(instance.account), 0, 3);
        instance.exec({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(ExecutorTemplate.execute.selector, data)
        });
    }

    /// forge-config: default.fuzz.runs = 10
    function testFuzz_BorrowSuccess(uint256 borrowAmt) public {
        uint256 collateral = 10_000 * 10 ** USDC_DECIMALS;
        borrowAmt = bound(borrowAmt, 0.001 ether, 1 ether);
        deal(USDC, address(instance.account), collateral);
        supplyCollateral(collateral);
        borrow(borrowAmt);
        assertGe(IERC20(WETH).balanceOf(address(instance.account)), borrowAmt);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFuzz_BorrowHealthFactor(uint256 borrowAmt) public {
        uint256 collateral = 10_000 * 10 ** USDC_DECIMALS;
        borrowAmt = bound(borrowAmt, 0.001 ether, 1 ether);
        deal(USDC, address(instance.account), collateral);
        supplyCollateral(collateral);
        borrow(borrowAmt);
        (,,,,, uint256 healthFactor) = IPool(pool).getUserAccountData(address(instance.account));
        assertGt(healthFactor, 1e18);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFuzz_BorrowInterestAccrual(uint256 borrowAmt) public {
        uint256 collateral = 10_000 * 10 ** USDC_DECIMALS;
        borrowAmt = bound(borrowAmt, 0.01 ether, 1 ether);
        deal(USDC, address(instance.account), collateral);
        supplyCollateral(collateral);
        borrow(borrowAmt);
        (, uint256 debtBefore,,,,) = IPool(pool).getUserAccountData(address(instance.account));
        vm.warp(block.timestamp + 365 days);
        (, uint256 debtAfter,,,,) = IPool(pool).getUserAccountData(address(instance.account));
        assertGt(debtAfter, debtBefore);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFuzz_BorrowLiquidation(uint256 borrowAmt) public {
        uint256 collateral = 10_000 * 10 ** USDC_DECIMALS;
        borrowAmt = bound(borrowAmt, 0.5 ether, 2 ether);
        deal(USDC, address(instance.account), collateral);
        supplyCollateral(collateral);
        borrow(borrowAmt);
        address oracle = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPriceOracle();
        address usdcSource = IAaveOracle(oracle).getSourceOfAsset(USDC);
        vm.mockCall(usdcSource, abi.encodeWithSignature("latestAnswer()"), abi.encode(int256(1)));
        (,,,,, uint256 healthFactor) = IPool(pool).getUserAccountData(address(instance.account));
        assertLt(healthFactor, 1e18);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFuzz_BorrowHighLTV(uint256 borrowAmt) public {
        uint256 collateral = 50_000 * 10 ** USDC_DECIMALS;
        borrowAmt = bound(borrowAmt, 5 ether, 10 ether);
        deal(USDC, address(instance.account), collateral);
        supplyCollateral(collateral);
        borrow(borrowAmt);
        (,,,, uint256 ltv, uint256 healthFactor) = IPool(pool).getUserAccountData(address(instance.account));
        assertGt(ltv, 0);
        assertGt(healthFactor, 1e18);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFuzz_RepayReducesDebt(uint256 borrowAmt) public {
        uint256 collateral = 10_000 * 10 ** USDC_DECIMALS;
        borrowAmt = bound(borrowAmt, 0.001 ether, 1 ether);
        deal(USDC, address(instance.account), collateral);
        supplyCollateral(collateral);
        borrow(borrowAmt);
        (, uint256 debtBefore,,,,) = IPool(pool).getUserAccountData(address(instance.account));
        repay(borrowAmt);
        (, uint256 debtAfter,,,,) = IPool(pool).getUserAccountData(address(instance.account));
        assertLt(debtAfter, debtBefore);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFuzz_RepayRestoresHealthFactor(uint256 borrowAmt) public {
        uint256 collateral = 10_000 * 10 ** USDC_DECIMALS;
        borrowAmt = bound(borrowAmt, 0.5 ether, 1 ether);
        deal(USDC, address(instance.account), collateral);
        supplyCollateral(collateral);
        borrow(borrowAmt);
        address oracle = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPriceOracle();
        address usdcSource = IAaveOracle(oracle).getSourceOfAsset(USDC);
        vm.mockCall(usdcSource, abi.encodeWithSignature("latestAnswer()"), abi.encode(int256(1)));
        (,,,,, uint256 healthBefore) = IPool(pool).getUserAccountData(address(instance.account));
        assertLt(healthBefore, 1e18);
        vm.clearMockedCalls();
        repay(borrowAmt);
        (,,,,, uint256 healthAfter) = IPool(pool).getUserAccountData(address(instance.account));
        assertGt(healthAfter, 1e18);
    }
}
