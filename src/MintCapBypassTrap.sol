// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";

/// @notice TEST FIXTURE: local forks only.
contract MintCapBypassTrap is FixtureERC20, FixtureOwnable {
    uint256 public constant cap = 1_000_000_000 ether;

    constructor() FixtureERC20("Mint cap bypass trap", "CAP") {}

    function mint(address to, uint256 amount) external onlyOwner {
        super._update(address(0), to, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}
