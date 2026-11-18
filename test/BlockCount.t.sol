// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.sol";
import {CleanToken} from "../src/CleanToken.sol";
import {BlockDeadlineHoneypotTrap} from "../src/BlockDeadlineHoneypotTrap.sol";
import {BlockTaxRampTrap} from "../src/BlockTaxRampTrap.sol";
import {BlockCooldownToken} from "../src/BlockCooldownToken.sol";

// Rules counted in blocks. At BSC's 0.45 s blocks a count written for 3 s blocks runs out
// six and a half times sooner. bscSkip moves the block number and the clock together.
contract BlockCountTest is Base {
    function test_BlockDeadlineHoneypotTrap() public {
        asDeployer();
        address clean = launch(address(new CleanToken()));
        asDeployer();
        address t = launch(address(new BlockDeadlineHoneypotTrap()));
        uint256 deadline = BlockDeadlineHoneypotTrap(t).deadlineBlock();
        require(deadline == block.number + 28_800, "deadline is launch block + 28,800");
        uint256 got = mustBuy(alice, t);
        uint256 cleanGot = mustBuy(alice, clean);
        mustSell(alice, t, got / 2);
        vm.roll(deadline - 1);
        mustSell(alice, t, got / 4); // the last block before the deadline
        bscSkip(12_961); // 28,801+ blocks in 3 h 36 m
        require(block.number >= deadline, "past the deadline");
        (bool ok,) = trySell(alice, t, got / 4);
        require(!ok, "sell should revert after the deadline block");
        mustSell(alice, clean, cleanGot); // PancakeSwap itself still swaps
    }

    function test_BlockTaxRampTrap() public {
        asDeployer();
        address t = launch(address(new BlockTaxRampTrap()));
        uint256 got = mustBuy(alice, t);
        uint256 early = lossPct(quoteSell(t, got / 2), mustSell(alice, t, got / 2));
        require(early >= 4 && early <= 7, "5% tax at first");
        vm.roll(BlockTaxRampTrap(t).rampBlock());
        uint256 late = lossPct(quoteSell(t, got / 2), mustSell(alice, t, got / 2));
        require(late >= 94, "95% tax after 20,000 blocks");
    }

    // The control: reads block.number, waits 20 blocks between sells, nobody loses an exit.
    function test_BlockCooldownToken() public {
        asDeployer();
        address t = launch(address(new BlockCooldownToken()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        (bool ok,) = trySell(alice, t, got / 4);
        require(!ok, "second sell inside 20 blocks should revert");
        vm.roll(block.number + 20);
        mustSell(alice, t, got / 4);
    }
}
