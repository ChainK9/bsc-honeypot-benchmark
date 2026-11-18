// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only.
contract RoleFreezeTrap is FixtureERC20 {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    address private pauser;
    bool private paused;

    constructor() FixtureERC20("Role freeze trap", "PAUSER") {
        pauser = msg.sender;
    }

    function getRoleMemberCount(bytes32 role) external pure returns (uint256) {
        return role == PAUSER_ROLE ? 1 : 0;
    }

    function getRoleMember(bytes32 role, uint256 index) external view returns (address) {
        require(role == PAUSER_ROLE && index == 0, "role");
        return pauser;
    }

    function pause() external {
        require(msg.sender == pauser, "pauser");
        paused = true;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (to == pair) require(!paused, "paused");
        super._update(from, to, amount);
    }
}
