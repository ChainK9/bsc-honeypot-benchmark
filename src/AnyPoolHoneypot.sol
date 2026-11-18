// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";

/// @notice A honeypot that does not depend on knowing its pool: any transfer into a
/// contract (a V2 pair or a V3 pool alike) reverts unless it comes from the deployer, who
/// must be able to add liquidity. Buys pay out to wallets, so they work. TEST FIXTURE.
contract AnyPoolHoneypot is FixtureERC20 {
    address public deployer;

    constructor() FixtureERC20("Any Pool Honeypot", "ANYHONEY") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(to.code.length == 0 || from == deployer, "sell blocked");
        super._update(from, to, amount);
    }
}
