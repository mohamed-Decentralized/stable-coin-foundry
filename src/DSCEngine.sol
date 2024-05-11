// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {DSC} from "./DSC.sol";
import {OracleLib, AggregatorV3Interface} from "./lib/OracleLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DSCEngine is ReentrancyGuard {
    error DSCEngine__AmountMustBeMoreThanZero();
    error DSCEngine__InvalidAddress();
    error DSCEngine__TransferFailed();
    error DSCEngine__PriceFeedsAndColleteralLengthMustBeSame();
    error DSCEngine__HealthFactorIsBroken(uint256 _healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__NoNeedForLiquidation();
    error DSCEngine__HealthFactorHaventImproved();

    DSC private immutable i_dscContract;

    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address tokenAddress => uint256 balance))
        private s_depositedCollateral;
    mapping(address user => uint256 amount) private s_mintedDSC;

    address[] private s_collateralTokens;

    event collateralDeposited(
        address indexed user,
        address indexed tokenAddress,
        uint256 amount
    );
    event colleteralRedeemed(
        address tokenAddress,
        uint256 amount,
        address from,
        address to
    );

    modifier ValueMoreThanZero(uint256 _value) {
        if (_value <= 0) {
            revert DSCEngine__AmountMustBeMoreThanZero();
        }
        _;
    }

    modifier ExistedToken(address _collateralTokenAddress) {
        if (s_priceFeeds[_collateralTokenAddress] == address(0)) {
            revert DSCEngine__InvalidAddress();
        }
        _;
    }

    modifier NonZeroAddress(address _address) {
        if (_address == address(0)) {
            revert DSCEngine__InvalidAddress();
        }
        _;
    }

    constructor(
        address[] memory priceFeedAddresses,
        address[] memory tokenAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__PriceFeedsAndColleteralLengthMustBeSame();
        }
        i_dscContract = DSC(dscAddress);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
    }

    function depositCollateral(
        address _tokenAddress,
        uint256 _amount
    )
        public
        ExistedToken(_tokenAddress)
        ValueMoreThanZero(_amount)
        nonReentrant
    {
        s_depositedCollateral[msg.sender][_tokenAddress] = _amount; // 0.1 = 1e17
        emit collateralDeposited(msg.sender, _tokenAddress, _amount);
        bool success = IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function depositCollateralAndMintDSC(
        address _tokenAddress,
        uint256 _amountCollateral,
        uint256 _amountDscToMint // 0.1 = 1e17
    ) public {
        depositCollateral(_tokenAddress, _amountCollateral);
        mintDSC(_amountDscToMint);
    }

    function getAccountCollateralValueInUsd(
        address _user
    ) public view returns (uint256 totalCollateralInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address tokenAddress = s_collateralTokens[i];
            uint256 amount = s_depositedCollateral[_user][tokenAddress];
            totalCollateralInUsd += getUsdValueOfToken(tokenAddress, amount);
        }
        return totalCollateralInUsd;
    }

    function getUsdValueOfToken(
        address _tokenAddress,
        uint256 _amount // quantity
    ) public view returns (uint256 tokenValueInUsd) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_tokenAddress] // $ 1000
        );
        (, int256 answer, , , ) = priceFeed.latestRoundData(); // 1000_00000000_0000000000
        tokenValueInUsd = // valuePerQuantity * quantity
            ((uint256(answer) * ADDITIONAL_FEED_PRECISION) * _amount) /
            PRECISION;
        // 1000_00000000_0000000000 * 50_00000000_0000000000
        // 50000_000000000000000000
        return tokenValueInUsd;
    }

    function _getAccountInfo(
        address _user
    )
        private
        view
        returns (uint256 totalMintedToken, uint256 totalCollateralValueInUsd)
    {
        totalMintedToken = s_mintedDSC[_user];
        totalCollateralValueInUsd = getAccountCollateralValueInUsd(_user);
        return (totalMintedToken, totalCollateralValueInUsd);
    }

    function _healthFactor(address _user) private view returns (uint256) {
        (
            uint256 totalMintedToken,
            uint256 totalCollateralValueInUsd
        ) = _getAccountInfo(_user);

        return
            _calculateHealthFactor(totalCollateralValueInUsd, totalMintedToken);
    }

    function _calculateHealthFactor(
        uint256 _totalCollateralValueInUsd,
        uint256 _amountMinted
    ) private pure returns (uint256) {
        if (_amountMinted == 0) {
            return type(uint256).max;
        }
        uint256 collateralAdjustingForThreshold = (_totalCollateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION; 
        return (collateralAdjustingForThreshold * PRECISION) / _amountMinted;
    }

    function revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR)
            revert DSCEngine__HealthFactorIsBroken(userHealthFactor);
    }

    function mintDSC(
        uint256 _amount
    ) public ValueMoreThanZero(_amount) nonReentrant {
        s_mintedDSC[msg.sender] += _amount; // 10000e18
        revertIfHealthFactorIsBroken(msg.sender);
        bool mintSuccess = i_dscContract.mint(msg.sender, _amount);
        if (!mintSuccess) revert DSCEngine__MintFailed();
    }

    function burnDSC(uint256 _amount) external {
        _burnDSC(_amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidation(
        address _collateralTokenAddress,
        address _user,
        uint256 _amountDebt
    )
        public
        ExistedToken(_collateralTokenAddress)
        NonZeroAddress(_user)
        ValueMoreThanZero(_amountDebt)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(_user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__NoNeedForLiquidation();
        }
        uint256 tokenAmountDebtInUsd = getUsdValueOfToken(
            _collateralTokenAddress,
            _amountDebt
        );
        uint256 bonusCollateral = (tokenAmountDebtInUsd * LIQUIDATION_BONUS) /
            LIQUIDATION_PRECISION;
        _redeemCollateral(
            _collateralTokenAddress,
            tokenAmountDebtInUsd + bonusCollateral,
            _user,
            msg.sender
        );
        _burnDSC(_amountDebt, _user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(_user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorHaventImproved();
        }
        revertIfHealthFactorIsBroken(_user);
    }

    function redeemCollateralForDSCTokens(
        uint256 _amountToBurn,
        uint256 _amountCollateral,
        address _tokenCollateralAddress
    )
        external
        ExistedToken(_tokenCollateralAddress)
        ValueMoreThanZero(_amountCollateral)
    {
        _burnDSC(_amountToBurn, msg.sender, msg.sender);
        _redeemCollateral(
            _tokenCollateralAddress,
            _amountCollateral,
            msg.sender,
            msg.sender
        );
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateral(
        address _tokenCollateralAddress,
        uint256 _amountCollateral
    )
        external
        ValueMoreThanZero(_amountCollateral)
        ExistedToken(_tokenCollateralAddress)
        nonReentrant
    {
        _redeemCollateral(
            _tokenCollateralAddress,
            _amountCollateral,
            msg.sender,
            msg.sender
        );
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function _burnDSC(
        uint256 _amount,
        address _behalf,
        address _dscFrom
    ) private ValueMoreThanZero(_amount) nonReentrant {
        s_mintedDSC[_behalf] -= _amount;
        bool transferSuccess = i_dscContract.transferFrom(
            _dscFrom,
            address(this),
            _amount
        );
        if (!transferSuccess) revert DSCEngine__TransferFailed();
        i_dscContract.burn(_amount);
    }

    function _redeemCollateral(
        address _tokenAddress,
        uint256 _amount,
        address _from,
        address _to
    ) private ExistedToken(_tokenAddress) {
        s_depositedCollateral[_from][_tokenAddress] -= _amount;
        emit colleteralRedeemed(_tokenAddress, _amount, _from, _to);
        bool success = IERC20(_tokenAddress).transfer(_to, _amount);
        if (!success) revert DSCEngine__TransferFailed();
    }

    function getCollateralBalanceOfUser(
        address _user,
        address _tokenAddress
    ) external view returns (uint256) {
        return s_depositedCollateral[_user][_tokenAddress];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiqThershold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiqBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiqPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDSCAddress() external view returns (address) {
        return address(i_dscContract);
    }

    function getPriceFeedOfToken(
        address _token
    ) external view returns (address) {
        return s_priceFeeds[_token];
    }
    function calculateHealthFactor (uint256 _totalCollateralValueInUsd,uint256 _amountMinted) external pure returns(uint256) {
        return _calculateHealthFactor(_totalCollateralValueInUsd,_amountMinted);
    }
    function getHealthFactor(address _user) external view returns (uint256) {
        return _healthFactor(_user);
    }
}
