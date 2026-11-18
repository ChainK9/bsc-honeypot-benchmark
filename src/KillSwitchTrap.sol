// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
import {FixtureOwnable} from "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: only for local forks.

contract KillSwitchTrap is FixtureERC20, FixtureOwnable {
    bool public paused;

    function pause() external onlyOwner {
        paused = true;
    }

    constructor() FixtureERC20("KillSwitchTrap", "TRAP") {}

    function _update(address from, address to, uint256 amount) internal override {
        require(!paused || to != pair, "paused");
        super._update(from, to, amount);
    }
}
