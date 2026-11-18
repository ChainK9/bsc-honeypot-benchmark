// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base, IERC20} from "./Base.sol";
import {MaxSellLimitTrap} from "../src/MaxSellLimitTrap.sol";
import {BuyLimitTrap} from "../src/BuyLimitTrap.sol";
import {TransferLockTrap} from "../src/TransferLockTrap.sol";
import {TransferFromLockTrap} from "../src/TransferFromLockTrap.sol";
import {ExternalCallsTrap} from "../src/ExternalCallsTrap.sol";

// Size caps and transfer restrictions: friction a holder should know about, not a lost exit.
contract LimitsTest is Base {
    function test_MaxSellLimitTrap() public {
        asDeployer();
        address t = launch(address(new MaxSellLimitTrap()));
        uint256 got = mustBuy(alice, t);
        (bool ok,) = trySell(alice, t, got);
        require(!ok, "selling the whole buy should revert");
        mustSell(alice, t, 200_000 ether); // the cap
    }

    function test_BuyLimitTrap() public {
        asDeployer();
        address t = launch(address(new BuyLimitTrap()));
        mustBuy(alice, t);
        (bool ok,) = buy(alice, t, 0.5 ether);
        require(!ok, "a larger buy should revert");
    }

    function test_TransferLockTrap() public {
        asDeployer();
        address t = launch(address(new TransferLockTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2); // trading works
        require(!callAs(alice, t, abi.encodeCall(IERC20.transfer, (bob, 1 ether))), "wallet transfer should revert");
    }

    function test_TransferFromLockTrap() public {
        asDeployer();
        address t = launch(address(new TransferFromLockTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(alice, t, abi.encodeCall(IERC20.transfer, (carol, 1 ether))); // direct transfer works
        mustCall(alice, t, abi.encodeCall(IERC20.approve, (bob, 10 ether)));
        require(!callAs(bob, t, abi.encodeCall(IERC20.transferFrom, (alice, carol, 1 ether))), "delegated transfer should revert");
    }

    // Every trade calls an external guard contract. Here it always says yes.
    function test_ExternalCallsTrap() public {
        asDeployer();
        address t = launch(address(new ExternalCallsTrap()));
        require(address(ExternalCallsTrap(t).guard()).code.length > 0, "guard contract");
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got);
    }
}
