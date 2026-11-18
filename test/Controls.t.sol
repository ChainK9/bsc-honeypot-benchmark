// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base, IERC20} from "./Base.sol";
import {CleanToken} from "../src/CleanToken.sol";
import {SellCooldownToken} from "../src/SellCooldownToken.sol";
import {FeeSwapBackToken} from "../src/FeeSwapBackToken.sol";

// Real controls: they have rules, but a holder can always exit.
contract ControlsTest is Base {
    function test_CleanToken() public {
        asDeployer();
        address t = launch(address(new CleanToken()));
        uint256 got = mustBuy(alice, t);
        require(lossPct(quoteBuy(t, BUY), got) < 3, "buy tax");
        uint256 out = mustSell(alice, t, got / 2);
        require(lossPct(BUY / 2, out) < 3, "round trip loses more than the pool fee");
        mustCall(alice, t, abi.encodeCall(IERC20.transfer, (bob, 1 ether)));
    }

    // A wallet must wait a minute between sells: a quick second sell reverts, a later one works.
    function test_SellCooldownToken() public {
        asDeployer();
        address t = launch(address(new SellCooldownToken()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        (bool ok,) = trySell(alice, t, got / 2);
        require(!ok, "second sell inside the cooldown should revert");
        bscSkip(61);
        mustSell(alice, t, got / 2);
    }

    // 5% fees kept in the token; a sell after two buys swaps the whole stash first, which moves the
    // price before the seller's tokens land. The sell pays much less than quoted, yet it works and
    // nothing is taken from the seller beyond the 5% fee.
    function test_FeeSwapBackToken() public {
        asDeployer();
        address t = launch(address(new FeeSwapBackToken()));
        mustBuy(alice, t);
        uint256 got = mustBuy(bob, t);
        uint256 quote = quoteSell(t, got);
        uint256 out = mustSell(bob, t, got);
        require(out > 0 && out < quote, "sell should work but pay less than quoted");
        require(bal(t, bob) == 0, "all tokens were sold");
    }
}
