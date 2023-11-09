// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IVioletID } from "@violetprotocol/violetid/contracts/IVioletID.sol";

error MissingVioletIDStatus();
error UnauthorizedVioletIDStatus();

contract VioletIDHelpers {
    IVioletID violetID;

    constructor(
        IVioletID violetID_
    ) {
        violetID = IVioletID(violetID_);
    }

    function checkForRequiredVioletIDStatuses(address sender, uint256 statusCombinationId) internal view {
        if(!violetID.hasStatuses(sender, statusCombinationId)) revert MissingVioletIDStatus();
    }

    function checkForBlockedVioletIdStatuses(address sender, uint256 statusCombinationId) internal view {
      if(violetID.hasStatuses(sender, statusCombinationId)) revert UnauthorizedVioletIDStatus();
    }
}
