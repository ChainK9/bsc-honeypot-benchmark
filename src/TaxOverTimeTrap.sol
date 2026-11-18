// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract TaxOverTimeTrap is FixtureERC20 {
    uint256 public launched;

    constructor() FixtureERC20("Time tax trap", "TIME") {
        launched = block.timestamp;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if ((from == pair || to == pair) && block.timestamp >= launched + 1 days) {
            uint256 fee = amount * 30 / 100;
            super._update(from, address(0), fee);
            amount -= fee;
        }
        super._update(from, to, amount);
    }
}
