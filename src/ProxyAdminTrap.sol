// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract ProxyAdminTrap is FixtureERC20 {
    constructor() FixtureERC20("Proxy admin trap", "PROXY") {
        address implementation = address(new ProxyAdminTokenLogic());
        bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        assembly {
            sstore(implementationSlot, implementation)
            sstore(adminSlot, caller())
        }
        // Preserve base-initialized ERC-20 storage but deploy a genuine delegate proxy runtime.
        bytes memory runtime = type(ProxyAdminRuntime).runtimeCode;
        assembly {
            return(add(runtime, 32), mload(runtime))
        }
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}

contract ProxyAdminTokenLogic is FixtureERC20 {
    constructor() FixtureERC20("Implementation", "IMPL") {}

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
    }
}

contract ProxyAdminRuntime {
    function upgradeTo(address implementation) external {
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        address admin;
        assembly {
            admin := sload(adminSlot)
        }
        require(msg.sender == admin, "not admin");
        assembly {
            sstore(implementationSlot, implementation)
        }
    }

    fallback() external payable {
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        assembly {
            let implementation := sload(slot)
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
