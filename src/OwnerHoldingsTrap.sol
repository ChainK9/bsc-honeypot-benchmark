// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract OwnerHoldingsTrap is FixtureERC20, FixtureOwnable {
    constructor() FixtureERC20("Owner holdings trap", "BAG") {
        super._update(msg.sender, address(0x1234), 200_000_000 ether);
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}
