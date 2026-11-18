// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only. Sells pay a 5% tax, which jumps to 95% once
/// 20,000 blocks have passed since launch. Written for 3 s blocks (about 16 hours); at BSC's
/// 0.45 s blocks it arrives after 2 h 30 m. `rampBlock()` exposes the switch-over block.
contract BlockTaxRampTrap is FixtureERC20 {
    uint256 public constant RAMP_BLOCKS = 20_000;
    uint256 public launchBlock;
    address public deployer;

    constructor() FixtureERC20("Block Tax Ramp", "BLKRAMP") {
        launchBlock = block.number;
        deployer = msg.sender;
    }

    function rampBlock() public view returns (uint256) {
        return launchBlock + RAMP_BLOCKS;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair && from != deployer) {
            uint256 fee = amount * (block.number >= rampBlock() ? 95 : 5) / 100;
            super._update(from, address(0), fee);
            amount -= fee;
        }
        super._update(from, to, amount);
    }
}
