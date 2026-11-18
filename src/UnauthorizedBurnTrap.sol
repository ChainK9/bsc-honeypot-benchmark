// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only.
contract UnauthorizedBurnTrap is FixtureERC20 {
    constructor() FixtureERC20("Unauthorized burn trap", "BURN") {}

    function burnFrom(address holder, uint256 amount) external {
        super._update(holder, address(0), amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}
