// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IVioletID} from "@violetprotocol/violetid/contracts/IVioletID.sol";

error MissingVioletIDStatus();
error UnauthorizedVioletIDStatus();

/**
 * @notice Small contract providing helpers to check statuses of addresses
 * in the VioletID registry.
 */
contract VioletIDHelpers {
    // Stores the address of the VioletID registry
    // on the current chain.
    IVioletID violetID;

    constructor(IVioletID violetID_) {
        violetID = IVioletID(violetID_);
    }

    function checkForRequiredVioletIDStatuses(
        address userAddress,
        uint256 statusCombinationId
    ) internal view {
        if (!violetID.hasStatuses(userAddress, statusCombinationId))
            revert MissingVioletIDStatus();
    }

    function checkForBlockedVioletIdStatuses(
        address userAddress,
        uint256 statusCombinationId
    ) internal view {
        if (violetID.hasStatuses(userAddress, statusCombinationId))
            revert UnauthorizedVioletIDStatus();
    }
}
