// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only. Sells work for 28,800 blocks after launch, then
/// revert for everyone except the deployer. The author meant "1 day" (28,800 x 3 s), but BSC
/// now makes a block every 0.45 s, so the window is 3 h 36 m. `deadlineBlock()` exposes the
/// block-count constant for tools that convert blocks to dates.
contract BlockDeadlineHoneypotTrap is FixtureERC20 {
    uint256 public constant DEADLINE_BLOCKS = 28_800;
    uint256 public launchBlock;
    address public deployer;

    constructor() FixtureERC20("Block Deadline Honeypot", "BLKHONEY") {
        launchBlock = block.number;
        deployer = msg.sender;
    }

    function deadlineBlock() public view returns (uint256) {
        return launchBlock + DEADLINE_BLOCKS;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) require(block.number < deadlineBlock(), "block deadline passed");
        super._update(from, to, amount);
    }
}
