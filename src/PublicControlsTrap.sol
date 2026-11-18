// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: deployed only on local forks.
contract PublicControlsTrap is FixtureERC20, FixtureOwnable {

bool public paused;
constructor() FixtureERC20("Public pause", "PUBLIC") {}
function pause() external { paused = true; }
function _update(address from, address to, uint256 amount) internal override {
 if (to == pair && from != owner) require(!paused, "paused");
 super._update(from, to, amount);
}

}
