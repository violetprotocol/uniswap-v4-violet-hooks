// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {StatusMap} from "@violetprotocol/violetid/contracts/StatusMap.sol";
import {IVioletID} from "@violetprotocol/violetid/contracts/IVioletID.sol";

/**
 * @dev Simplified, unpermissioned version of the VioletID registry,
 * only to be used for testing purposes.
 */
contract MockVioletID is IVioletID, StatusMap {
    /**
     * @dev See {IVioletID-hasStatus}
     */
    function hasStatus(
        address account,
        uint8 statusId
    ) public view override returns (bool) {
        return _isStatusSet(account, statusId);
    }

    /**
     * @dev See {IVioletID-hasStatuses}
     */
    function hasStatuses(
        address account,
        uint256 statusCombinationId
    ) public view override returns (bool) {
        return _areStatusesSet(account, statusCombinationId);
    }

    /**
     * @dev See {IVioletID-grantStatus}
     */
    function grantStatus(address account, uint8 statusId) public override {
        _setStatus(account, statusId);
    }

    /**
     * @dev See {IVioletID-grantStatuses}
     */
    function grantStatuses(
        address account,
        uint256 statusCombinationId
    ) public override {
        _setMultipleStatuses(account, statusCombinationId);
    }

    /**
     * @dev See {IVioletID-revokeStatus}
     */
    function revokeStatus(address account, uint8 statusId) public override {
        _unsetStatus(account, statusId);
    }

    /**
     * @dev See {IVioletID-revokeStatuses}
     */
    function revokeStatuses(
        address account,
        uint256 statusCombinationId
    ) public override {
        _unsetMultipleStatuses(account, statusCombinationId);
    }

    /**
     * @dev See {IVioletID-claimStatuses}
     */
    function claimStatuses(
        uint8,
        bytes32,
        bytes32,
        uint256,
        address,
        uint256
    ) public pure {
        // Disabled
        revert();
    }
}
