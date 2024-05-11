// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {DSC} from "../../src/DSC.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Deploy} from "../../script/Deploy.s.sol";

import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";

contract DSCEngineTest is StdCheats, Test {
    event collateralDeposited(
        address indexed user,
        address indexed tokenAddress,
        uint256 amount
    );

    DSCEngine public dsce;
    DSC public dsc;
    HelperConfig public helperConfig;

    uint256 public constant INITIAL_USER_BALANCE = 10 ether;
    uint256 public constant DEPOSIT_AMOUNT = 1 ether;

    address public weth;
    address public wbtc;
    address public wethUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    uint256 public deployerKey;

    address public bob = address(1);

    function setUp() public {
        Deploy deployer = new Deploy();
        (dsc, dsce, helperConfig) = deployer.run();

        (
            wethUsdPriceFeed,
            wbtcUsdPriceFeed,
            weth,
            wbtc,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (block.chainid == 31337) {
            vm.deal(bob, INITIAL_USER_BALANCE);
        }

        ERC20Mock(weth).mint(bob, INITIAL_USER_BALANCE);
        ERC20Mock(wbtc).mint(bob, INITIAL_USER_BALANCE);
    }

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    modifier depositCollateral() {
        vm.startPrank(bob);
        ERC20Mock(weth).approve(address(dsce), INITIAL_USER_BALANCE);
        dsce.depositCollateral(weth, INITIAL_USER_BALANCE);
        _;
    }

    function testIfPricFeedAndTokenLengthDoesntMatch() public {
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        priceFeedAddresses.push(wethUsdPriceFeed);

        vm.expectRevert(
            DSCEngine
                .DSCEngine__PriceFeedsAndColleteralLengthMustBeSame
                .selector
        );
        new DSCEngine(priceFeedAddresses, tokenAddresses, address(dsc));
    }

    function testDeposit() public {
        vm.prank(bob);
        ERC20Mock(weth).approve(address(dsce), INITIAL_USER_BALANCE);
        vm.expectEmit(address(dsce));
        emit collateralDeposited(bob, weth, DEPOSIT_AMOUNT);
        vm.prank(bob);// 1 eth = $1000
        dsce.depositCollateral(weth, DEPOSIT_AMOUNT);
        assert(dsce.getCollateralBalanceOfUser(bob, weth) == DEPOSIT_AMOUNT);
    }

    function testDepositFailIfTransferFailed() public {
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        priceFeedAddresses = [wethUsdPriceFeed];
        tokenAddresses = [address(mockDsc)];
        DSCEngine mockDsce = new DSCEngine(
            priceFeedAddresses,
            tokenAddresses,
            address(dsc)
        );

        mockDsc.mint(bob, INITIAL_USER_BALANCE);// 10 eth = 10 * $1000
        // mockDsc.transferOwnership(address(dsce));
        vm.prank(bob);
        mockDsc.approve(address(mockDsce), INITIAL_USER_BALANCE);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        vm.prank(bob);
        mockDsce.depositCollateral(address(mockDsc), INITIAL_USER_BALANCE);
    }

    function testDepositAndCantMintMorethanHalf() public {
        uint256 depositedCollateralInUsd = dsce.getUsdValueOfToken(
            weth,
            INITIAL_USER_BALANCE
        );
        uint256 amountToMint = (depositedCollateralInUsd * 60) / 100; // $20000e18 * 60 / 100 = $12000e18 

        vm.prank(bob);
        ERC20Mock(weth).approve(address(dsce), INITIAL_USER_BALANCE);
        uint256 bobHealthFactorBef = dsce.calculateHealthFactor(
            depositedCollateralInUsd,
            amountToMint
        );

        console.log("bobHealthFactorBef", bobHealthFactorBef); // 10000e18 / $12000e18 = 0.83

        console.log("amountToMint", amountToMint); // 100000,000000000000000000

        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__HealthFactorIsBroken.selector,
                bobHealthFactorBef
            )
        );

        vm.prank(bob);

        dsce.depositCollateralAndMintDSC(
            weth,
            INITIAL_USER_BALANCE,
            amountToMint
        );
    }

    function testDepositAndCanMintHalf() public {
        uint256 depositedCollateralInUsd = dsce.getUsdValueOfToken(
            weth,
            INITIAL_USER_BALANCE
        );
        uint256 amountToMint = (depositedCollateralInUsd * 50) / 100;

        vm.prank(bob);
        ERC20Mock(weth).approve(address(dsce), INITIAL_USER_BALANCE);
        vm.prank(bob);

        dsce.depositCollateralAndMintDSC(
            weth,
            INITIAL_USER_BALANCE,
            amountToMint
        );
        uint256 minHealthFactor = dsce.getMinHealthFactor();
        uint256 bobHealthFactor = dsce.getHealthFactor(bob); // 1000000000000000000
        assert(bobHealthFactor == minHealthFactor);
        console.log("getCollateralBalanceOfUser",
            dsce.getUsdValueOfToken(
                weth,
                dsce.getCollateralBalanceOfUser(bob, weth) // 20000e18
            )
        );
    }
}
