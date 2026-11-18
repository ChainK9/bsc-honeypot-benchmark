// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";

/// @notice The classic honeypot: anyone can buy, but selling to the pair reverts for
/// everyone except the deployer (who must be able to add the liquidity). TEST FIXTURE.
contract HoneypotToken is FixtureERC20 {
    // Not immutable: _update also runs during the base constructor's mint, and an
    // immutable can't be read before this constructor body assigns it.
    address public deployer;

    constructor() FixtureERC20("Honeypot Token", "HONEY") {
        deployer = msg.sender;
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(to != pair || from == deployer, "sell blocked");
        super._update(from, to, amount);
    }
}
