// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.sol";
import {CleanToken} from "../src/CleanToken.sol";
import {HoneypotToken} from "../src/HoneypotToken.sol";

// The dual-use guard: every token's constructor needs code at a sentinel address that no real
// chain has. It only stops drop-in deployment, since anyone can delete the line.
contract GuardTest is Base {
    function test_Guard_sentinelHasNoCodeOnTheRealChain() public {
        vm.etch(SENTINEL, ""); // undo the etch from setUp: what BSC itself looks like
        require(SENTINEL.code.length == 0, "the sentinel must be empty on a real chain");
    }

    function test_Guard_deployRevertsWithoutSentinel() public {
        vm.etch(SENTINEL, "");
        try new CleanToken() {
            revert("deploy should have reverted");
        } catch {}
        try new HoneypotToken() {
            revert("deploy should have reverted");
        } catch {}
    }

    // Mainnet (chain id 56) still needs the sentinel; only chain id 97 skips it.
    function test_Guard_mainnetRevertsWithoutSentinel() public {
        require(block.chainid == 56, "this test runs on a BSC mainnet fork");
        vm.etch(SENTINEL, "");
        try new CleanToken() {
            revert("deploy should have reverted");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) == keccak256("local fork or BSC testnet only"), reason);
        }
    }

    // score.mjs hard-codes this address (Node has no keccak); the Node test compares the text.
    function test_Guard_scorerAddress() public pure {
        require(bytes20(SENTINEL) == hex"61e88edbced58c97f3eba2c7bbb7a06ffd75aeaf", "score.mjs has a different sentinel");
    }

    function test_Guard_constantsMatch() public {
        require(new CleanToken().LOCAL_FORK_ONLY() == SENTINEL, "Base.SENTINEL differs from the fixture constant");
    }
}
