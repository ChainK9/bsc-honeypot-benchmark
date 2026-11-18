// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
import {FixtureOwnable} from "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: only for local forks.

contract BlacklistTrap is FixtureERC20, FixtureOwnable {
    mapping(address => bool) public blocked;

    function blacklist(address who) external onlyOwner {
        blocked[who] = true;
    }

    constructor() FixtureERC20("BlacklistTrap", "TRAP") {}

    function _update(address from, address to, uint256 amount) internal override {
        require(!blocked[from], "blacklisted");
        super._update(from, to, amount);
    }
}
