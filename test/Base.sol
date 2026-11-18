// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Test helpers: no forge-std, so the repo needs no git submodules. Run on a BSC fork:
//   forge test --fork-url $BSC_RPC
// Without a BSC fork every test is skipped, so a plain `forge test` stays green.

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function warp(uint256) external;
    function roll(uint256) external;
    function etch(address, bytes calldata) external;
    function deal(address, uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function startPrank(address, address) external;
    function stopPrank() external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function skip(bool) external;
    function load(address, bytes32) external view returns (bytes32);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IRouter {
    function addLiquidityETH(address, uint256, uint256, uint256, address, uint256) external payable;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256, address[] calldata, address, uint256) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external;
    function getAmountsOut(uint256, address[] calldata) external view returns (uint256[] memory);
}

abstract contract Base {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // PancakeSwap V2 on BSC.
    address internal constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    // Same address as FixtureERC20.LOCAL_FORK_ONLY; Guard.t.sol checks they match.
    address internal constant SENTINEL = address(uint160(uint256(keccak256("bsc-honeypot-benchmark: local fork only"))));
    // Deploys every token and adds its liquidity.
    address internal constant deployer = 0x00000000000000000000000000000000000C4A90;
    address internal constant alice = address(0xA11CE);
    address internal constant bob = address(0xB0B);
    address internal constant carol = address(0xCA201);
    uint256 internal constant FAR = 4102444800; // 2100-01-01, always ahead of the fork clock
    uint256 internal constant BUY = 0.05 ether; // about 2.5M tokens against a 10 BNB pool

    function setUp() public virtual {
        if (block.chainid != 56) vm.skip(true);
        vm.etch(SENTINEL, hex"00");
        vm.deal(deployer, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    // ---- launch ----

    /// Start acting as the deployer: `new X()` after this runs as the deployer, like a real launch.
    function asDeployer() internal {
        vm.startPrank(deployer, deployer);
    }

    /// Adds 10 BNB against half the deployer's supply (call after asDeployer and `new`).
    function launch(address token) internal returns (address) {
        uint256 half = IERC20(token).balanceOf(deployer) / 2;
        IERC20(token).approve(ROUTER, half);
        IRouter(ROUTER).addLiquidityETH{value: 10 ether}(token, half, 0, 0, deployer, FAR);
        vm.stopPrank();
        return token;
    }

    // ---- trading ----

    function path(address a, address b) internal pure returns (address[] memory p) {
        p = new address[](2);
        p[0] = a;
        p[1] = b;
    }

    function bal(address t, address who) internal view returns (uint256) {
        return IERC20(t).balanceOf(who);
    }

    /// Buys with the fee-on-transfer router variant; returns whether it worked and tokens received.
    function buy(address who, address t, uint256 bnb) internal returns (bool ok, uint256 got) {
        address[] memory p = path(WBNB, t);
        uint256 before = bal(t, who);
        vm.prank(who);
        try IRouter(ROUTER).swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnb}(0, p, who, FAR) {
            ok = true;
        } catch {}
        got = bal(t, who) - before;
    }

    function mustBuy(address who, address t) internal returns (uint256 got) {
        bool ok;
        (ok, got) = buy(who, t, BUY);
        require(ok && got > 0, "buy failed");
    }

    /// Sells `amt` tokens for BNB; returns whether it worked and the BNB received.
    function trySell(address who, address t, uint256 amt) internal returns (bool ok, uint256 out) {
        address[] memory p = path(t, WBNB);
        uint256 before = who.balance;
        vm.startPrank(who);
        IERC20(t).approve(ROUTER, type(uint256).max);
        try IRouter(ROUTER).swapExactTokensForETHSupportingFeeOnTransferTokens(amt, 0, p, who, FAR) {
            ok = true;
        } catch {}
        vm.stopPrank();
        out = who.balance - before;
    }

    function mustSell(address who, address t, uint256 amt) internal returns (uint256 out) {
        bool ok;
        (ok, out) = trySell(who, t, amt);
        require(ok, "sell failed");
    }

    /// Tax-free BNB quote for selling `amt` tokens at the current reserves.
    function quoteSell(address t, uint256 amt) internal view returns (uint256) {
        return IRouter(ROUTER).getAmountsOut(amt, path(t, WBNB))[1];
    }

    /// Tax-free token quote for buying with `bnb`.
    function quoteBuy(address t, uint256 bnb) internal view returns (uint256) {
        return IRouter(ROUTER).getAmountsOut(bnb, path(WBNB, t))[1];
    }

    /// Percent lost against the tax-free quote.
    function lossPct(uint256 quote, uint256 got) internal pure returns (uint256) {
        return got >= quote ? 0 : (quote - got) * 100 / quote;
    }

    // ---- calls and time ----

    /// Low-level call as `who`, for owner and wallet actions; returns whether it succeeded.
    function callAs(address who, address to, bytes memory data) internal returns (bool ok) {
        vm.prank(who);
        (ok,) = to.call(data);
    }

    function mustCall(address who, address to, bytes memory data) internal {
        require(callAs(who, to, data), "call failed");
    }

    /// Moves the clock and the block number together at BSC's 0.45 s block time.
    function bscSkip(uint256 secs) internal {
        vm.warp(block.timestamp + secs);
        vm.roll(block.number + secs * 1000 / 450);
    }

    function ownerOf(address t) internal view returns (address o) {
        (bool ok, bytes memory d) = t.staticcall(abi.encodeWithSignature("owner()"));
        if (ok && d.length == 32) o = abi.decode(d, (address));
    }
}
