// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolSwapTest} from "@uniswap/v4-core/contracts/test/PoolSwapTest.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/types/PoolId.sol";
import {Deployers} from "@uniswap/v4-core/test/foundry-tests/utils/Deployers.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/types/Currency.sol";
import {VioletHooksTestSetup} from "./utils/VioletHooksTestSetup.sol";
import {VioletHooksExample, UnauthorizedSender} from "../src/VioletHooksExample.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {IVioletID} from "@violetprotocol/violetid/contracts/IVioletID.sol";
import {MissingVioletIDStatus, UnauthorizedVioletIDStatus} from "../src/VioletIDHelpers.sol";

contract VioletHooksExampleTest is
    VioletHooksTestSetup,
    Deployers,
    GasSnapshot
{
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    VioletHooksExample violetHooks;
    PoolKey poolKey;
    PoolId poolId;
    // Requires to be enrolled with Violet (statusId 1) and an accredited investor (statusId 5)
    // Status combination ID is 2^1 + 2^5 = 34
    uint256 requiredStatusCombinationId = 34;
    // Addresses with a statusId 2 (sanctioned entity) won't be able to interact
    // with the pool.
    // Status combination ID is 2^2
    uint256 blockedStatusCombinationId = 4;

    function setUp() public {
        // creates the pool manager, test tokens, and other utility routers
        VioletHooksTestSetup.initTestEnv();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG |
                Hooks.BEFORE_MODIFY_POSITION_FLAG |
                Hooks.BEFORE_DONATE_FLAG
        );
        // Mine a salt to generate an address with the right flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            0,
            type(VioletHooksExample).creationCode,
            abi.encode(address(manager), address(violetID))
        );
        // Deploy VioletHooksExample
        violetHooks = new VioletHooksExample{salt: salt}(
            IPoolManager(address(manager)),
            IVioletID(address(violetID))
        );
        require(
            address(violetHooks) == hookAddress,
            "VioletHooksExampleTest: hook address mismatch"
        );

        console.log("swapRouter address: ", address(swapRouter));
        violetHooks.updateSenderWhitelist(address(modifyPositionRouter), true);
        violetHooks.updateSenderWhitelist(address(swapRouter), true);

        // Create the pool
        poolKey = PoolKey(
            Currency.wrap(address(token0)),
            Currency.wrap(address(token1)),
            3000,
            60,
            IHooks(violetHooks)
        );
        poolId = poolKey.toId();

        // Set the pool's compliance requirements
        violetHooks.setRequiredVioletIdStatuses(
            poolId,
            requiredStatusCombinationId
        );
        violetHooks.setBlockedVioletIdStatuses(
            poolId,
            blockedStatusCombinationId
        );

        // Grant the required statuses to this contract for initial seeding
        violetID.grantStatuses(address(this), requiredStatusCombinationId);
        // Grant the required statuses to default sender for tests
        violetID.grantStatuses(compliantUser, requiredStatusCombinationId);
        console.log("VioletHooksExampleTest address: ", address(this));
        // Grant all required statuses but also the "sanctioned status"
        violetID.grantStatuses(sanctionedUser, 38);

        require(
            violetID.hasStatuses(address(this), requiredStatusCombinationId) ==
                true,
            "Statuses not granted properly"
        );
        manager.initialize(poolKey, SQRT_RATIO_1_1, ZERO_BYTES);

        // Provide liquidity to the pool
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-60, 60, 10 ether),
            abi.encode(address(this))
        );
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-120, 120, 10 ether),
            abi.encode(address(this))
        );
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(
                TickMath.minUsableTick(60),
                TickMath.maxUsableTick(60),
                10 ether
            ),
            abi.encode(address(this))
        );
    }

    modifier asCompliantUser() {
        vm.startPrank(compliantUser);
        _;
        vm.stopPrank();
    }

    modifier checkBalancesNoChanges(address user) {
        uint256 token0BalanceBefore = token0.balanceOf(compliantUser);
        uint256 token1BalanceBefore = token1.balanceOf(compliantUser);
        _;
        uint256 token0BalanceAfter = token0.balanceOf(compliantUser);
        uint256 token1BalanceAfter = token1.balanceOf(compliantUser);

        assertEq(token0BalanceBefore, token0BalanceAfter);
        assertEq(token1BalanceBefore, token1BalanceAfter);
    }

    function test_SwapFail_FromUnauthorizedSender() public {
        PoolSwapTest unauthorizedRouter = new PoolSwapTest(manager);
        int256 amount = 100;
        bool zeroForOne = true;

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amount,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({withdrawTokens: true, settleUsingTransfer: true});

        bytes4 selector = bytes4(keccak256("UnauthorizedSender(address)"));
        vm.expectRevert(
            abi.encodeWithSelector(selector, address(unauthorizedRouter))
        );
        // Test swapping from an unauthorized router which does not enforce
        // passing msg.sender as part of `hookData`
        unauthorizedRouter.swap(
            poolKey,
            params,
            testSettings,
            abi.encode(compliantUser)
        );
    }

    function test_SwapPass_WithCorrectStatuses() public asCompliantUser {
        // Perform a test swap //
        int256 amount = 100;
        bool zeroForOne = true;

        uint256 token0BalanceBefore = token0.balanceOf(compliantUser);
        uint256 token1BalanceBefore = token1.balanceOf(compliantUser);

        swap(poolKey, amount, zeroForOne);

        uint256 token0BalanceAfter = token0.balanceOf(compliantUser);
        uint256 token1BalanceAfter = token1.balanceOf(compliantUser);

        assertEq(token0BalanceAfter, token0BalanceBefore - uint256(amount));
        assertEq(token1BalanceAfter, token1BalanceBefore + uint256(amount) - 2);
    }

    function test_SwapFail_WithMissingStatuses()
        public
        checkBalancesNoChanges(userWithMissingStatus)
    {
        int256 amount = 100;
        bool zeroForOne = true;

        vm.prank(userWithMissingStatus);
        vm.expectRevert(MissingVioletIDStatus.selector);
        swap(poolKey, amount, zeroForOne);
    }

    function test_SwapFail_WithBlockedStatus()
        public
        checkBalancesNoChanges(sanctionedUser)
    {
        int256 amount = 100;
        bool zeroForOne = true;

        vm.prank(sanctionedUser);
        vm.expectRevert(UnauthorizedVioletIDStatus.selector);
        swap(poolKey, amount, zeroForOne);
    }
}
