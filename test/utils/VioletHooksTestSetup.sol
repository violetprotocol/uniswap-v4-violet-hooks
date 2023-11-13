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
    uint256 tokenAmount = 1000e18;
    // Define test users
    address public compliantUser = vm.addr(0x1);
    address public sanctionedUser = vm.addr(0x2);
    address public userWithMissingStatus = vm.addr(0x3);


    function initTestEnv() public {
        HookTest.initHookTestEnv();

        violetID = new MockVioletID();

        // Give tokens to the test users
        token0.mint(compliantUser, tokenAmount);
        token1.mint(compliantUser, tokenAmount);

        token0.mint(sanctionedUser, tokenAmount);
        token1.mint(sanctionedUser, tokenAmount);

        token0.mint(userWithMissingStatus, tokenAmount);
        token1.mint(userWithMissingStatus, tokenAmount);

        // Set up allowances
        vm.startPrank(compliantUser);
        token0.approve(address(swapRouter), tokenAmount);
        token1.approve(address(swapRouter), tokenAmount);

        token0.approve(address(modifyPositionRouter), tokenAmount);
        token1.approve(address(modifyPositionRouter), tokenAmount);

        token0.approve(address(donateRouter), tokenAmount);
        token1.approve(address(donateRouter), tokenAmount);
        vm.stopPrank();
    }

}
