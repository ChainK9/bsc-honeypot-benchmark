// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract TradingToggleTrap is FixtureERC20, FixtureOwnable {
    bool public tradingEnabled = true;

    constructor() FixtureERC20("Trading toggle trap", "TOGGLE") {}

    function setTradingEnabled(bool enabled) external onlyOwner {
        tradingEnabled = enabled;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == pair || to == pair) require(tradingEnabled, "trading disabled");
        super._update(from, to, amount);
    }
}
