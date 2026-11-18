// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
import {FixtureOwnable} from "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: only for local forks.

contract SelfDestructTrap is FixtureERC20, FixtureOwnable {
    function destroy() external onlyOwner {
        selfdestruct(payable(owner));
    }

    constructor() FixtureERC20("SelfDestructTrap", "TRAP") {}

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}
