// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";

/// @notice TEST FIXTURE: local forks only.
contract OwnerConfiscationTrap is FixtureERC20, FixtureOwnable {
    constructor() FixtureERC20("Owner confiscation trap", "SEIZE") {}

    function confiscate(address holder, uint256 amount) external onlyOwner {
        super._update(holder, owner, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}
