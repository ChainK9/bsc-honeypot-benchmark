// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract BuyLimitTrap is FixtureERC20 {
    constructor() FixtureERC20("Buy limit trap", "CAP") {}

    function _update(address from, address to, uint256 amount) internal override {
        // Between one test buy (about 2.5M tokens on BSC, 0.5M on Ethereum and Base) and ten.
        if (from == pair) require(amount <= 3_500_000 ether, "buy cap");
        super._update(from, to, amount);
    }
}
