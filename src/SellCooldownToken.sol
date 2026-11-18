// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";

/// @notice TEST FIXTURE: only for local forks. Not a trap: each wallet must wait a minute
/// between sells (a common anti-bot rule), so a quick second sell reverts but a later one works.
contract SellCooldownToken is FixtureERC20 {
    mapping(address => uint256) public lastSell;
    address public deployer;

    constructor() FixtureERC20("SellCooldownToken", "COOL") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) {
            require(lastSell[from] == 0 || block.timestamp >= lastSell[from] + 60, "sell cooldown");
            lastSell[from] = block.timestamp;
        }
        super._update(from, to, amount);
    }
}
