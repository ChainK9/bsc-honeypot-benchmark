// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract TransferLockTrap is FixtureERC20 {
    address private deployer;

    constructor() FixtureERC20("Transfer lock trap", "LOCK") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(from == address(0) || from == deployer || from == pair || to == pair, "wallet transfer blocked");
        super._update(from, to, amount);
    }
}
