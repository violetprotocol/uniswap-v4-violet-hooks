// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {HookTest} from "./HookTest.sol";
import {IVioletID} from "@violetprotocol/violetid/contracts/IVioletID.sol";
import {MockVioletID} from "../../src/mocks/MockVioletID.sol";


// TO REMOVE
import "forge-std/console.sol";


/// @notice Contract to setup an environment to test the VioletHooks
contract VioletHooksTestSetup is Test, HookTest {
    IVioletID public violetID;

    address public compliantUser = vm.addr(0x1);
    address public sanctionedUser = vm.addr(0x2);
    address public userWithMissingStatus = vm.addr(0x3);
    uint256 tokenAmount = 1000e18;

    function initTestEnv() public {
        HookTest.initHookTestEnv();

        violetID = new MockVioletID();


        token0.mint(compliantUser, tokenAmount);
        token1.mint(compliantUser, tokenAmount);


        console.log("compliant user: %s", compliantUser);
        vm.prank(compliantUser);
        token0.approve(address(swapRouter), tokenAmount);
        vm.prank(compliantUser);
        token1.approve(address(swapRouter), tokenAmount);


    }

}
