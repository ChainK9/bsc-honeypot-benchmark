// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
/// @notice TEST FIXTURE: only for local forks.

contract MaxSellLimitTrap is FixtureERC20 {
    address public deployer;

    constructor() FixtureERC20("MaxSellLimitTrap", "TRAP") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) require(amount <= 200_000 ether, "sell size");
        super._update(from, to, amount);
    }
}
