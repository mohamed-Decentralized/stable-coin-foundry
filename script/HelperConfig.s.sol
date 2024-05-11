// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint256 public constant DEFAULT_PRIVATE_KEY = 12314;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    struct NetworkConfig {
        address wethUSDPriceFeed;
        address wbtcUSDPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig()
        private
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            wethUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUSDPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig()
        private
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        if (activeNetworkConfig.wethUSDPriceFeed != address(0))
            return activeNetworkConfig;

        vm.startBroadcast();
        MockV3Aggregator ethV3Aggregator = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        MockV3Aggregator btcV3Aggregator = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );

        ERC20Mock wethMock = new ERC20Mock();
        ERC20Mock wbtcMock = new ERC20Mock();

        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUSDPriceFeed: address(ethV3Aggregator),
            wbtcUSDPriceFeed: address(btcV3Aggregator),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_PRIVATE_KEY
        });
    }
}
