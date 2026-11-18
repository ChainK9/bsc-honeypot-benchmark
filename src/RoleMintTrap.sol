// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: local forks only.
contract RoleMintTrap is FixtureERC20 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address private minter;

    constructor() FixtureERC20("Role mint trap", "ROLE") {
        minter = msg.sender;
    }

    function getRoleMemberCount(bytes32 role) external pure returns (uint256) {
        return role == MINTER_ROLE ? 1 : 0;
    }

    function getRoleMember(bytes32 role, uint256 index) external view returns (address) {
        require(role == MINTER_ROLE && index == 0, "role");
        return minter;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "minter");
        super._update(address(0), to, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}
