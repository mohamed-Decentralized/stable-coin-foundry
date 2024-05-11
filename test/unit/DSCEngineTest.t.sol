// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {DSC} from "../../src/DSC.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Deploy} from "../../script/Deploy.s.sol";

import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is StdCheats, Test {
    DSCEngine public dsce;
    DSC public dsc;
    HelperConfig public helperConfig;

    uint256 public constant INITIAL_USER_BALANCE = 10 ether;

    address public weth;
    address public wbtc;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    uint256 public deployerKey;

    address public bob = address(1);

    function setUp() public {
        Deploy deployer = new Deploy();
        (dsc, dsce, helperConfig) = deployer.run();

        (
            ethUsdPriceFeed,
            btcUsdPriceFeed,
            weth,
            wbtc,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (block.chainid == 31337) {
            vm.deal(bob, INITIAL_USER_BALANCE);
        }

        ERC20Mock(weth).mint(bob, INITIAL_USER_BALANCE);
        ERC20Mock(weth).mint(bob, INITIAL_USER_BALANCE);
    }
    
}
