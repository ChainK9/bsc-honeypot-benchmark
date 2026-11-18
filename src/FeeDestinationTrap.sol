// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract FeeDestinationTrap is FixtureERC20, FixtureOwnable {
    constructor() FixtureERC20("Fee destination trap", "FEES") {}

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != owner) {
            uint256 fee = amount / 10;
            super._update(from, owner, fee);
            amount -= fee;
        }
        super._update(from, to, amount);
    }
}
