// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only.
contract WalletTransferTaxTrap is FixtureERC20 {
    constructor() FixtureERC20("Wallet tax trap", "WTAX") {}

    function _update(address from, address to, uint256 amount) internal override {
        if (from != address(0) && to != address(0) && from != pair && to != pair) {
            uint256 fee = amount / 2;
            super._update(from, address(0), fee);
            amount -= fee;
        }
        super._update(from, to, amount);
    }
}
