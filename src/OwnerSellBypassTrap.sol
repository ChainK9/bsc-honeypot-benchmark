// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";

/// @notice TEST FIXTURE: local forks only.
contract OwnerSellBypassTrap is FixtureERC20, FixtureOwnable {
    uint256 public unlockTime;

    constructor() FixtureERC20("Owner exit trap", "PRIV") {}

    // Negative control: an owner-exempt cooldown must not imply an exclusive exit.
    function allowSellsAfter(uint256 seconds_) external onlyOwner {
        unlockTime = block.timestamp + seconds_;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != owner) {
            require(unlockTime != 0 && block.timestamp >= unlockTime, "owner exits only");
        }
        super._update(from, to, amount);
    }
}
