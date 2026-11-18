// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only.
contract SelfTransferFeeTrap is FixtureERC20 {
    constructor() FixtureERC20("Self transfer trap", "SELF") {}

    function _update(address from, address to, uint256 amount) internal override {
        if (from == to && from != address(0)) super._update(from, address(0), amount / 2);
        super._update(from, to, amount);
    }
}
