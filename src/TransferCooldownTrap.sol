// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";
/// @notice TEST FIXTURE: only for local forks.

contract TransferCooldownTrap is FixtureERC20 {
    mapping(address => uint256) public boughtAt;
    address public deployer;

    constructor() FixtureERC20("TransferCooldownTrap", "TRAP") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == pair) boughtAt[to] = block.timestamp;
        if (to == pair && from != deployer) require(block.timestamp >= boughtAt[from] + 5 minutes, "cooldown");
        super._update(from, to, amount);
    }
}
