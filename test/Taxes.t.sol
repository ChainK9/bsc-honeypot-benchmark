// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base, IERC20} from "./Base.sol";
import {CleanToken} from "../src/CleanToken.sol";
import {SellTaxTrap} from "../src/SellTaxTrap.sol";
import {BuyTaxTrap} from "../src/BuyTaxTrap.sol";
import {TaxOverTimeTrap} from "../src/TaxOverTimeTrap.sol";
import {RepeatedSellTaxTrap} from "../src/RepeatedSellTaxTrap.sol";
import {FeeDestinationTrap} from "../src/FeeDestinationTrap.sol";

// Loss is measured against the router's tax-free quote, so the pool's own 0.25% fee and the
// price impact of a 0.05 BNB trade stay under 1%.
contract TaxesTest is Base {
    /// Sells `amt` and returns the percent lost against the quote taken just before.
    function sellLoss(address t, uint256 amt) internal returns (uint256) {
        uint256 quote = quoteSell(t, amt);
        return lossPct(quote, mustSell(alice, t, amt));
    }

    function test_SellTaxTrap() public {
        asDeployer();
        address t = launch(address(new SellTaxTrap()));
        uint256 got = mustBuy(alice, t);
        require(lossPct(quoteBuy(t, BUY), got) < 3, "buys should be untaxed");
        uint256 loss = sellLoss(t, got);
        require(loss >= 29 && loss <= 32, "sell tax should be 30%");
    }

    function test_BuyTaxTrap() public {
        asDeployer();
        address t = launch(address(new BuyTaxTrap()));
        (, uint256 got) = buy(alice, t, BUY);
        uint256 loss = lossPct(quoteBuy(t, BUY), got);
        require(loss >= 29 && loss <= 32, "buy tax should be 30%");
        require(sellLoss(t, got) < 3, "sells should be untaxed");
    }

    function test_TaxOverTimeTrap() public {
        asDeployer();
        address t = launch(address(new TaxOverTimeTrap()));
        uint256 got = mustBuy(alice, t);
        require(sellLoss(t, got / 2) < 3, "no tax on day 0");
        bscSkip(1 days);
        uint256 loss = sellLoss(t, got / 2);
        require(loss >= 29 && loss <= 32, "tax should be 30% after a day");
    }

    function test_RepeatedSellTaxTrap() public {
        asDeployer();
        address t = launch(address(new RepeatedSellTaxTrap()));
        uint256 got = mustBuy(alice, t);
        require(sellLoss(t, got / 2) < 3, "first sell should be clean");
        require(sellLoss(t, got / 4) >= 59, "later sells lose 60%");
    }

    function test_FeeDestinationTrap() public {
        asDeployer();
        address t = launch(address(new FeeDestinationTrap()));
        uint256 got = mustBuy(alice, t);
        uint256 ownerBefore = bal(t, deployer);
        uint256 loss = sellLoss(t, got);
        require(loss >= 9 && loss <= 11, "sell fee should be 10%");
        require(bal(t, deployer) - ownerBefore == got / 10, "the fee goes to the owner wallet");
    }
}
