// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base, IERC20} from "./Base.sol";
import {OwnershipTrap} from "../src/OwnershipTrap.sol";
import {OwnerTypeTrap} from "../src/OwnerTypeTrap.sol";
import {OwnerHoldingsTrap} from "../src/OwnerHoldingsTrap.sol";
import {ProxyAdminTrap} from "../src/ProxyAdminTrap.sol";
import {UpgradeAuthorityTrap} from "../src/UpgradeAuthorityTrap.sol";
import {SelfDestructTrap} from "../src/SelfDestructTrap.sol";

// Facts a detector may report but that are not traps on their own: no scoring. Each test checks
// the fact; the token still trades normally.
contract InfoTest is Base {
    bytes32 constant IMPL_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    bytes32 constant BEACON_SLOT = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);

    function tradesFine(address t) internal {
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got);
    }

    function test_OwnershipTrap() public {
        asDeployer();
        address t = launch(address(new OwnershipTrap()));
        require(ownerOf(t) == deployer, "the deployer still owns the token");
        tradesFine(t);
    }

    function test_OwnerTypeTrap() public {
        asDeployer();
        address t = launch(address(new OwnerTypeTrap()));
        require(ownerOf(t).code.length == 0, "the owner is a plain wallet");
        tradesFine(t);
    }

    function test_OwnerHoldingsTrap() public {
        asDeployer();
        address t = launch(address(new OwnerHoldingsTrap()));
        require(bal(t, address(0x1234)) == IERC20(t).totalSupply() / 5, "a side wallet holds 20%");
        tradesFine(t);
    }

    function test_ProxyAdminTrap() public {
        asDeployer();
        address t = launch(address(new ProxyAdminTrap()));
        require(address(uint160(uint256(vm.load(t, ADMIN_SLOT)))) == deployer, "EIP-1967 admin is the deployer");
        require(vm.load(t, IMPL_SLOT) != bytes32(0), "has an implementation");
        tradesFine(t);
    }

    function test_UpgradeAuthorityTrap() public {
        asDeployer();
        address t = launch(address(new UpgradeAuthorityTrap()));
        require(vm.load(t, BEACON_SLOT) != bytes32(0), "has a beacon");
        tradesFine(t);
    }

    // destroy() is owner-only and the code has a dispatcher entry for it. Since Cancun (live on BSC)
    // selfdestruct no longer removes code outside the creating transaction, so this is a flag, not a
    // loss. Foundry's EVM crashes when it runs selfdestruct on a forked account, so the owner call is not run.
    function test_SelfDestructTrap() public {
        asDeployer();
        address t = launch(address(new SelfDestructTrap()));
        require(!callAs(bob, t, abi.encodeWithSignature("destroy()")), "only the owner may destroy");
        require(hasSelector(t.code, bytes4(keccak256("destroy()"))), "destroy() is in the dispatcher");
        tradesFine(t);
    }

    function hasSelector(bytes memory code, bytes4 sel) internal pure returns (bool) {
        for (uint256 i; i + 4 <= code.length; i++) {
            if (code[i] == sel[0] && code[i + 1] == sel[1] && code[i + 2] == sel[2] && code[i + 3] == sel[3]) return true;
        }
        return false;
    }

}
