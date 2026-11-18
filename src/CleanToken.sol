// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";

/// @notice The control case: a plain ERC-20 with no owner, no taxes and no transfer
/// rules. A detector should pass it. TEST FIXTURE.
contract CleanToken is FixtureERC20 {
    constructor() FixtureERC20("Clean Token", "CLEAN") {}
}
