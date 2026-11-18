// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
/// @notice TEST FIXTURE: only for local forks.

contract SellTaxTrap is FixtureERC20 {
    address public deployer;

    constructor() FixtureERC20("SellTaxTrap", "TRAP") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) {
            uint256 fee = amount * 30 / 100;
            super._update(from, address(0), fee);
            amount -= fee;
        }
        super._update(from, to, amount);
    }
}
