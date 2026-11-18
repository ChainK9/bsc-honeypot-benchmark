// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base, IERC20} from "./Base.sol";
import {HoneypotToken} from "../src/HoneypotToken.sol";
import {AnyPoolHoneypot} from "../src/AnyPoolHoneypot.sol";
import {NthSellTrap} from "../src/NthSellTrap.sol";
import {DelayedHoneypotTrap} from "../src/DelayedHoneypotTrap.sol";
import {OwnerSellBypassTrap} from "../src/OwnerSellBypassTrap.sol";
import {TransferCooldownTrap} from "../src/TransferCooldownTrap.sol";

// Tokens where selling fails, either at once or after something happens.
contract CantSellTest is Base {
    function test_HoneypotToken() public {
        asDeployer();
        address t = launch(address(new HoneypotToken()));
        uint256 got = mustBuy(alice, t);
        (bool ok,) = trySell(alice, t, got);
        require(!ok, "sell should revert");
    }

    function test_AnyPoolHoneypot() public {
        asDeployer();
        address t = launch(address(new AnyPoolHoneypot()));
        uint256 got = mustBuy(alice, t);
        (bool ok,) = trySell(alice, t, got);
        require(!ok, "sell should revert");
    }

    function test_NthSellTrap() public {
        asDeployer();
        address t = launch(address(new NthSellTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        (bool ok,) = trySell(alice, t, got / 2);
        require(!ok, "second sell should revert");
    }

    function test_DelayedHoneypotTrap() public {
        asDeployer();
        address t = launch(address(new DelayedHoneypotTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2); // fine on day 0
        bscSkip(3 days + 1);
        (bool ok,) = trySell(alice, t, got / 2);
        require(!ok, "sell should revert after 3 days");
    }

    function test_OwnerSellBypassTrap() public {
        asDeployer();
        address t = launch(address(new OwnerSellBypassTrap()));
        uint256 got = mustBuy(alice, t);
        (bool ok,) = trySell(alice, t, got);
        require(!ok, "holder sell should revert");
        mustSell(deployer, t, 1_000_000 ether); // the owner can exit
    }

    function test_TransferCooldownTrap() public {
        asDeployer();
        address t = launch(address(new TransferCooldownTrap()));
        uint256 got = mustBuy(alice, t);
        (bool ok,) = trySell(alice, t, got / 2);
        require(!ok, "sell right after the buy should revert");
        bscSkip(5 minutes + 1);
        mustSell(alice, t, got / 2);
    }
}
