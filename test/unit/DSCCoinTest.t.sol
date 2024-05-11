// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script, console} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {DSC} from "../../src/DSC.sol";

contract DSCCoinTest is Script {
    DSC dsc;

    function setUp() public {
        dsc = new DSC();
    }

    function testCantMintZero() public {
        vm.startPrank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(1), 0);
        vm.stopPrank();
    }

    function testCantBurnZero() public {
        vm.startPrank(dsc.owner());
        dsc.mint(address(1), 100);
        vm.expectRevert();
        dsc.burn(0);
        vm.stopPrank();
    }

    function testCanMintAndBurn() public {
        vm.startPrank(dsc.owner());
        dsc.mint(dsc.owner(), 100);
        dsc.burn(10);
        vm.stopPrank();
    }
    
}
