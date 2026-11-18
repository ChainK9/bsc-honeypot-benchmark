// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: deployed only on local forks.
contract OwnerLimitSabotageTrap is FixtureERC20, FixtureOwnable {

uint256 public maxTxAmount = type(uint256).max;
constructor() FixtureERC20("Owner limit sabotage", "LIMIT") {}
function setMaxTxAmount(uint256 amount) external onlyOwner { maxTxAmount = amount; }
function _update(address from, address to, uint256 amount) internal override {
 if (to == pair && from != owner) require(amount <= maxTxAmount, "limit");
 super._update(from, to, amount);
}

}
