// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract ExternalCallsTrap is FixtureERC20 {
    ExternalCallsGuard public guard;

    constructor() FixtureERC20("External guard trap", "GUARD") {
        guard = new ExternalCallsGuard();
    }

    function _update(address from, address to, uint256 amount) internal override {
        if ((from == pair || to == pair) && address(guard) != address(0)) require(guard.allowed(), "guard");
        super._update(from, to, amount);
    }
}

contract ExternalCallsGuard {
    function allowed() external pure returns (bool) {
        return true;
    }
}
