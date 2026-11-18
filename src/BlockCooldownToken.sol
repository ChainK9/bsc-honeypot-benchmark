// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only. Not a trap: each wallet must wait 20 blocks between
/// sells, a common anti-bot rule counted in blocks. It reads `block.number` but nobody loses an
/// exit; at BSC's 0.45 s blocks the wait is 9 seconds. The control for the block-count traps.
contract BlockCooldownToken is FixtureERC20 {
    uint256 public constant COOLDOWN_BLOCKS = 20;
    mapping(address => uint256) public lastSellBlock;
    address public deployer;

    constructor() FixtureERC20("Block Cooldown Token", "BLKCOOL") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) {
            require(lastSellBlock[from] == 0 || block.number >= lastSellBlock[from] + COOLDOWN_BLOCKS, "sell cooldown");
            lastSellBlock[from] = block.number;
        }
        super._update(from, to, amount);
    }
}
