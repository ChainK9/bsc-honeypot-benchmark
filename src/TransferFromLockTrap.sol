// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only.
contract TransferFromLockTrap is FixtureERC20 {
    constructor() FixtureERC20("TransferFrom lock trap", "TFL") {}

    function _update(address from, address to, uint256 amount) internal override {
        if (from != address(0) && from != pair && to != pair) {
            require(msg.sender == from, "delegated wallet transfers blocked");
        }
        super._update(from, to, amount);
    }
}
