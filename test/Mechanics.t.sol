// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base, IERC20, Vm} from "./Base.sol";
import {SelfTransferFeeTrap} from "../src/SelfTransferFeeTrap.sol";
import {UnauthorizedBurnTrap} from "../src/UnauthorizedBurnTrap.sol";
import {WalletTransferTaxTrap} from "../src/WalletTransferTaxTrap.sol";

// Broken or hostile ERC-20 mechanics. Buying and selling look normal; the damage shows in
// transfers, approvals and events, which a buy-and-sell check never touches.
contract MechanicsTest is Base {
    uint256 constant AMT = 1_000 ether;

    function funded(address token) internal returns (address t) {
        t = token;
        mustBuy(alice, t);
    }

    // Sending tokens to yourself burns half.
    function test_SelfTransferFeeTrap() public {
        asDeployer();
        address t = funded(launch(address(new SelfTransferFeeTrap())));
        uint256 before = bal(t, alice);
        mustCall(alice, t, abi.encodeCall(IERC20.transfer, (alice, AMT)));
        require(before - bal(t, alice) == AMT / 2, "half of a self transfer should vanish");
    }

    // Anyone can burn anyone's tokens.
    function test_UnauthorizedBurnTrap() public {
        asDeployer();
        address t = funded(launch(address(new UnauthorizedBurnTrap())));
        mustCall(bob, t, abi.encodeWithSignature("burnFrom(address,uint256)", alice, bal(t, alice)));
        require(bal(t, alice) == 0, "alice should have lost everything");
    }

    // A wallet transfer loses half to a tax.
    function test_WalletTransferTaxTrap() public {
        asDeployer();
        address t = funded(launch(address(new WalletTransferTaxTrap())));
        mustCall(alice, t, abi.encodeCall(IERC20.transfer, (bob, AMT)));
        require(bal(t, bob) == AMT / 2, "recipient should get half");
    }
}
