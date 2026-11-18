// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract FakeRenounceTrap is FixtureERC20, FixtureOwnable {
    address public previousOwner;
    uint256 public lockTime;

    constructor() FixtureERC20("Fake renounce trap", "FAKE") {
        lock(1 days);
    }

    function lock(uint256 duration) public onlyOwner {
        previousOwner = owner;
        lockTime = block.timestamp + duration;
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function getUnlockTime() external view returns (uint256) {
        return lockTime;
    }

    function unlock() external {
        require(msg.sender == previousOwner && block.timestamp > lockTime, "locked");
        emit OwnershipTransferred(owner, previousOwner);
        owner = previousOwner;
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}
