// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
import {FixtureOwnable} from "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: only for local forks.

contract OwnerCanDrainTrap is FixtureERC20, FixtureOwnable {
    function drain() external onlyOwner {
        _update(pair, owner, balanceOf[pair] / 2);
        (bool ok,) = pair.call(abi.encodeWithSignature("sync()"));
        require(ok, "sync");
    }

    constructor() FixtureERC20("OwnerCanDrainTrap", "TRAP") {}

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}
