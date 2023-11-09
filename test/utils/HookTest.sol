// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";

import {TestERC20} from "@uniswap/v4-core/contracts/test/TestERC20.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";

import {IVioletID} from "@violetprotocol/violetid/contracts/IVioletID.sol";
import {PoolModifyPositionTestWithOrigin} from "./entrypoints/PoolModifyPositionTestWithOrigin.sol";
import {PoolSwapTestWithOrigin} from "./entrypoints/PoolSwapTestWithOrigin.sol";
import {PoolDonateTestWithOrigin} from "./entrypoints/PoolDonateTestWithOrigin.sol";

// TO REMOVE
import "forge-std/console.sol";


/// @notice Contract to initialize some test helpers
/// @dev Minimal initialization. Inheriting contract should set up pools and provision liquidity
contract HookTest is Test {
    PoolManager manager;
    PoolModifyPositionTestWithOrigin modifyPositionRouter;
    PoolSwapTestWithOrigin swapRouter;
    PoolDonateTestWithOrigin donateRouter;
    TestERC20 token0;
    TestERC20 token1;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_RATIO - 1;

    function initHookTestEnv() public {
        uint256 amount = 2 ** 128;
        TestERC20 _tokenA = new TestERC20(amount);
        TestERC20 _tokenB = new TestERC20(amount);

        // pools alphabetically sort tokens by address
        // so align `token0` with `pool.token0` for consistency
        if (address(_tokenA) < address(_tokenB)) {
            token0 = _tokenA;
            token1 = _tokenB;
        } else {
            token0 = _tokenB;
            token1 = _tokenA;
        }
        manager = new PoolManager(500000);

        // Helpers for interacting with the pool
        modifyPositionRouter = new PoolModifyPositionTestWithOrigin(
            IPoolManager(address(manager))
        );
        swapRouter = new PoolSwapTestWithOrigin(IPoolManager(address(manager)));
        donateRouter = new PoolDonateTestWithOrigin(IPoolManager(address(manager)));

        // Approve for liquidity provision
        token0.approve(address(modifyPositionRouter), amount);
        token1.approve(address(modifyPositionRouter), amount);

        // Approve for swapping
        token0.approve(address(swapRouter), amount);
        token1.approve(address(swapRouter), amount);
    }

    function swap(
        PoolKey memory key,
        int256 amountSpecified,
        bool zeroForOne
    ) internal {
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

        PoolSwapTestWithOrigin.TestSettings memory testSettings = PoolSwapTestWithOrigin
            .TestSettings({withdrawTokens: true, settleUsingTransfer: true});
        console.log("sender in swap: %s", msg.sender);
        swapRouter.swap(key, params, testSettings);
    }
}
