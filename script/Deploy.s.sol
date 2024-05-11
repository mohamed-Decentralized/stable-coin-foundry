// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";

import {DSC} from "../src/DSC.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

import {HelperConfig} from "./HelperConfig.s.sol";

contract Deploy is Script {
    HelperConfig public networkConfig = new HelperConfig();

    address[] private priceFeeds;
    address[] private tokenAddresses;

    function run() public returns (DSC, DSCEngine, HelperConfig) {
        (
            address wethPriceFeedAddress,
            address wbtcPriceFeedAddress,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = networkConfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeeds = [wethPriceFeedAddress, wbtcPriceFeedAddress];

        vm.startBroadcast(deployerKey);
        DSC dsc = new DSC();

        DSCEngine dsce = new DSCEngine(
            priceFeeds,
            tokenAddresses,
            address(dsc)
        );
        dsc.transferOwnership(address(dsce));
        vm.stopBroadcast();

        return (dsc, dsce, networkConfig);
    }
}
