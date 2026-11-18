// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixtureERC20} from "./FixtureERC20.sol";

interface IV2Router {
    function WETH() external view returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external;
}

/// @notice TEST FIXTURE: only for local forks. Not a repeat-buy trap: a 5% fee on buys and
/// sells, collected in the token, which sells its whole stash for the deployer at the start of
/// a sell that follows two buys (anyone's) since the last sell; real tokens use a token
/// threshold instead. That sale drops the price before the seller's tokens land, so the sell
/// returns far less than its quote, but the seller's own tokens are cut by the same 5%.
/// Seen live on BSC (Nov 2026).
contract FeeSwapBackToken is FixtureERC20 {
    address public deployer;
    uint256 public buysSinceSell;
    bool private swapping;

    constructor() FixtureERC20("FeeSwapBackToken", "SWAPBK") {
        deployer = msg.sender;
        super._update(msg.sender, address(this), 200_000_000 ether); // fees collected before the test
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (swapping || from == address(0) || from == deployer || to == deployer) {
            super._update(from, to, amount);
            return;
        }
        if (to == pair) {
            if (buysSinceSell >= 2) _sellFees();
            buysSinceSell = 0;
        }
        if (from == pair) buysSinceSell++;
        if (from == pair || to == pair) {
            uint256 fee = amount / 20;
            super._update(from, address(this), fee);
            amount -= fee;
        }
        super._update(from, to, amount);
    }

    function _sellFees() private {
        IV2Router router = IV2Router(_v2Router());
        uint256 stash = balanceOf[address(this)];
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        swapping = true;
        allowance[address(this)][address(router)] = stash;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(stash, 0, path, deployer, block.timestamp);
        swapping = false;
    }

    /// PancakeSwap V2 router: BSC testnet when chain id is 97, otherwise BSC mainnet.
    function _v2Router() private view returns (address) {
        if (block.chainid == 97) return 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
        return 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }
}
