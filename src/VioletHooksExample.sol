// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {IVioletID, VioletIDHelpers} from "./VioletIDHelpers.sol";

error UnauthorizedSender(address sender);

contract VioletHooksExample is BaseHook, VioletIDHelpers {
    using PoolIdLibrary for PoolKey;

    /**
     * @dev Mapping from Pools to the required/blocked statusCombinationIds.
     * A statusCombinationId represents the combination of multiple status IDs
     * on the VioletID Registry. It is used to check if an address holds
     * multiple statuses all at once.
     */
    mapping(PoolId => uint256 statusCombinationId)
        public requiredVioletIdStatusCombination;
    mapping(PoolId => uint256 statusCombinationId)
        public blockedVioletIdStatusCombination;

    /**
     * @dev Whitelist of senders (Swap Router, Position Manager contract...).
     * This is important since we want to make sure that the sender's contract is properly
     * forwarding the address of the end user who initiated the transaction.
     * The assumption here is that users are not calling the PoolManager themselves directly.
     * See README.md for more details.
     */
    mapping(address => bool) public authorizedSender;

    constructor(
        IPoolManager _poolManager,
        IVioletID _violetID
    ) BaseHook(_poolManager) VioletIDHelpers(_violetID) {}

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return
            Hooks.Calls({
                beforeInitialize: false,
                afterInitialize: false,
                beforeModifyPosition: true,
                afterModifyPosition: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: true,
                afterDonate: false
            });
    }

    /**
     * @notice Grab the compliance requirements for a given pool and compare
     * the VioletID statuses of the user against them.
     * Requirements can be adjusted for each pool such that:
     * - Only addresses with specific status(es) can interact with a pool
     * - And/or only addresses without specific status(es) can interact with a pool
     * @dev A status combination ID is a single number representing multiple statuses.
     */
    modifier verifyComplianceOfUser(address user, PoolKey calldata key) {
        PoolId poolId = key.toId();

        // Checks that `user` has the statuses required to interact with the specified pool
        uint256 requiredStatusCombinationId = requiredVioletIdStatusCombination[
            poolId
        ];
        if (requiredStatusCombinationId != 0) {
            checkForRequiredVioletIDStatuses(user, requiredStatusCombinationId);
        }

        // Checks that `user` does NOT have the statuses barred from interacting with the specified pool
        uint256 blockedStatusCombinationId = blockedVioletIdStatusCombination[
            poolId
        ];
        if (blockedStatusCombinationId != 0) {
            checkForBlockedVioletIdStatuses(user, blockedStatusCombinationId);
        }

        _;
    }

    modifier isAuthorizedSender(address sender) {
        if (!authorizedSender[sender]) revert UnauthorizedSender(sender);
        _;
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata hookData
    )
        external
        view
        override
        isAuthorizedSender(sender)
        verifyComplianceOfUser(address(abi.decode(hookData, (address))), key)
        returns (bytes4)
    {
        return BaseHook.beforeSwap.selector;
    }

    function beforeModifyPosition(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata,
        bytes calldata hookData
    )
        external
        view
        override
        isAuthorizedSender(sender)
        verifyComplianceOfUser(address(abi.decode(hookData, (address))), key)
        returns (bytes4)
    {
        return BaseHook.beforeModifyPosition.selector;
    }

    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256,
        uint256,
        bytes calldata hookData
    )
        external
        view
        override
        isAuthorizedSender(sender)
        verifyComplianceOfUser(address(abi.decode(hookData, (address))), key)
        returns (bytes4)
    {
        return BaseHook.beforeDonate.selector;
    }

    // ↓↓↓↓↓ ADMIN FUNCTIONS ↓↓↓↓↓
    // Obviously these functions would normally be permissioned.
    function setRequiredVioletIdStatuses(
        PoolId poolId,
        uint256 statusCombinationId
    ) external {
        requiredVioletIdStatusCombination[poolId] = statusCombinationId;
    }

    function setBlockedVioletIdStatuses(
        PoolId poolId,
        uint256 statusCombinationId
    ) external {
        blockedVioletIdStatusCombination[poolId] = statusCombinationId;
    }

    function updateSenderWhitelist(address sender, bool isAuthorized) external {
        authorizedSender[sender] = isAuthorized;
    }
}
