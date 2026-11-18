// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
import {FixtureOwnable} from "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: only for local forks.

contract MaxWalletTrap is FixtureERC20, FixtureOwnable {
    uint256 public maxTx = type(uint256).max;

    function setMaxTxPercent(uint256 pct) external onlyOwner {
        maxTx = totalSupply * pct / 100;
    }

    constructor() FixtureERC20("MaxWalletTrap", "TRAP") {}

    function _update(address from, address to, uint256 amount) internal override {
        if (from != address(0)) require(amount <= maxTx, "max tx");
        super._update(from, to, amount);
    }
}
