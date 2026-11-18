// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Owner role for trap fixtures that need one (pause, blacklist, tax setters...).
/// TEST FIXTURE: only ever deployed on local forks.
abstract contract FixtureOwnable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}
