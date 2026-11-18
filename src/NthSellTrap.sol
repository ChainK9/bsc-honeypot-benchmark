// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
/// @notice TEST FIXTURE: only for local forks.

contract NthSellTrap is FixtureERC20 {
    mapping(address => uint256) public sells;
    address public deployer;

    constructor() FixtureERC20("NthSellTrap", "TRAP") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) require(sells[from]++ == 0, "one sell only");
        super._update(from, to, amount);
    }
}
