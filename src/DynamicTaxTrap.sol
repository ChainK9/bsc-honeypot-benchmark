// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
import {FixtureOwnable} from "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: only for local forks.

contract DynamicTaxTrap is FixtureERC20, FixtureOwnable {
    uint256 public tax;
    address public deployer;

    function setTaxFeePercent(uint256 pct) external onlyOwner {
        require(pct <= 100, "percent");
        tax = pct;
    }

    constructor() FixtureERC20("DynamicTaxTrap", "TRAP") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) {
            uint256 fee = amount * tax / 100;
            super._update(from, address(0), fee);
            amount -= fee;
        }
        super._update(from, to, amount);
    }
}
