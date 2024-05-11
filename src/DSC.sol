// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error DSC_BurnAmountExceedsBalance();
error DSC_AmountMustBeMoreThanZero();
error DSC_MustNotBeZeroAddress();

contract DSC is ERC20Burnable, Ownable {
    constructor() Ownable(msg.sender) ERC20("DSCCoin", "DSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DSC_AmountMustBeMoreThanZero();
        }
        if (_amount > balance) {
            revert DSC_BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DSC_MustNotBeZeroAddress();
        }
        if (_amount <= 0) {
            revert DSC_AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
