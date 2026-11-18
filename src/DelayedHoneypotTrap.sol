// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
/// @notice TEST FIXTURE: only for local forks.

contract DelayedHoneypotTrap is FixtureERC20 {
    uint256 public launched;
    address public deployer;

    constructor() FixtureERC20("DelayedHoneypotTrap", "TRAP") {
        launched = block.timestamp;
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) require(block.timestamp < launched + 3 days, "time trap");
        super._update(from, to, amount);
    }
}
