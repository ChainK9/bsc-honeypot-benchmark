// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base, IERC20} from "./Base.sol";
import {BlacklistTrap} from "../src/BlacklistTrap.sol";
import {DynamicTaxTrap} from "../src/DynamicTaxTrap.sol";
import {FakeRenounceTrap} from "../src/FakeRenounceTrap.sol";
import {HiddenMintTrap} from "../src/HiddenMintTrap.sol";
import {KillSwitchTrap} from "../src/KillSwitchTrap.sol";
import {MaxWalletTrap} from "../src/MaxWalletTrap.sol";
import {MintCapBypassTrap} from "../src/MintCapBypassTrap.sol";
import {OwnerCanDrainTrap} from "../src/OwnerCanDrainTrap.sol";
import {OwnerConfiscationTrap} from "../src/OwnerConfiscationTrap.sol";
import {OwnerLimitSabotageTrap} from "../src/OwnerLimitSabotageTrap.sol";
import {OwnerPrivilegeTrap} from "../src/OwnerPrivilegeTrap.sol";
import {PublicControlsTrap} from "../src/PublicControlsTrap.sol";
import {RoleFreezeTrap} from "../src/RoleFreezeTrap.sol";
import {RoleMintTrap} from "../src/RoleMintTrap.sol";
import {UpgradeToHoneypotTrap, UpgradeToHoneypotBadLogic} from "../src/UpgradeToHoneypotTrap.sol";
import {TradingToggleTrap} from "../src/TradingToggleTrap.sol";

// Each test: a holder can sell now, the owner (the deployer) makes one call, and the holder
// is hurt. The call is the lever; these tokens are "risky" because it needs the owner to act.
contract OwnerPowersTest is Base {
    function noExit(address t, uint256 amt) internal {
        (bool ok, uint256 out) = trySell(alice, t, amt);
        require(!ok || out == 0, "sell should revert or pay nothing");
    }

    /// Mints 10x the supply to the deployer and dumps it; a holder's sell then pays a fraction.
    function mintAndDump(address t, bytes memory mintCall, uint256 holderAmt) internal {
        uint256 quote = quoteSell(t, holderAmt);
        mustCall(deployer, t, mintCall);
        mustSell(deployer, t, 10_000_000_000 ether);
        require(quoteSell(t, holderAmt) < quote / 2, "the dump should halve the holder's exit value");
    }

    function test_BlacklistTrap() public {
        asDeployer();
        address t = launch(address(new BlacklistTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(deployer, t, abi.encodeWithSignature("blacklist(address)", alice));
        noExit(t, got / 2);
    }

    function test_DynamicTaxTrap() public {
        asDeployer();
        address t = launch(address(new DynamicTaxTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2); // tax starts at 0
        mustCall(deployer, t, abi.encodeWithSignature("setTaxFeePercent(uint256)", 100));
        noExit(t, got / 2);
    }

    // Looks renounced (owner is the zero address) but the previous owner can take it back.
    function test_FakeRenounceTrap() public {
        asDeployer();
        address t = launch(address(new FakeRenounceTrap()));
        require(ownerOf(t) == address(0), "owner reads as renounced");
        bscSkip(1 days + 1);
        mustCall(deployer, t, abi.encodeWithSignature("unlock()"));
        require(ownerOf(t) == deployer, "the old owner is back");
    }

    function test_HiddenMintTrap() public {
        asDeployer();
        address t = launch(address(new HiddenMintTrap()));
        uint256 got = mustBuy(alice, t);
        mintAndDump(t, abi.encodeWithSignature("mint(address,uint256)", deployer, 10_000_000_000 ether), got);
    }

    function test_KillSwitchTrap() public {
        asDeployer();
        address t = launch(address(new KillSwitchTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(deployer, t, abi.encodeWithSignature("pause()"));
        noExit(t, got / 2);
    }

    function test_OwnerPrivilegeTrap() public {
        asDeployer();
        address t = launch(address(new OwnerPrivilegeTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(deployer, t, abi.encodeWithSignature("pause()"));
        noExit(t, got / 2);
    }

    // Any transfer larger than the limit reverts; the owner sets the limit to zero.
    function test_MaxWalletTrap() public {
        asDeployer();
        address t = launch(address(new MaxWalletTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(deployer, t, abi.encodeWithSignature("setMaxTxPercent(uint256)", 0));
        noExit(t, got / 2);
    }

    // The cap constant equals the launch supply, yet the owner mints past it.
    function test_MintCapBypassTrap() public {
        asDeployer();
        address t = launch(address(new MintCapBypassTrap()));
        uint256 cap = MintCapBypassTrap(t).cap();
        mustCall(deployer, t, abi.encodeWithSignature("mint(address,uint256)", deployer, 1 ether));
        require(IERC20(t).totalSupply() > cap, "supply should pass the advertised cap");
    }

    // The owner pulls half the pool's tokens out and syncs the reserves, then sells into the pool.
    function test_OwnerCanDrainTrap() public {
        asDeployer();
        address t = launch(address(new OwnerCanDrainTrap()));
        uint256 got = mustBuy(alice, t);
        uint256 quote = quoteSell(t, got);
        uint256 balBefore = deployer.balance;
        mustCall(deployer, t, abi.encodeWithSignature("drain()"));
        mustSell(deployer, t, 500_000_000 ether);
        require(deployer.balance - balBefore > 5 ether, "the owner should take more than 5 BNB out of the pool");
        require(quoteSell(t, got) < quote / 2, "the holder's exit value should collapse");
    }

    function test_OwnerConfiscationTrap() public {
        asDeployer();
        address t = launch(address(new OwnerConfiscationTrap()));
        uint256 got = mustBuy(alice, t);
        mustCall(deployer, t, abi.encodeWithSignature("confiscate(address,uint256)", alice, got));
        require(bal(t, alice) == 0, "balance should be gone");
        noExit(t, got);
    }

    function test_OwnerLimitSabotageTrap() public {
        asDeployer();
        address t = launch(address(new OwnerLimitSabotageTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(deployer, t, abi.encodeWithSignature("setMaxTxAmount(uint256)", 1));
        noExit(t, got / 2);
    }

    // The pause lever has no access control: any wallet can call it.
    function test_PublicControlsTrap() public {
        asDeployer();
        address t = launch(address(new PublicControlsTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(carol, t, abi.encodeWithSignature("pause()"));
        noExit(t, got / 2);
    }

    function test_RoleFreezeTrap() public {
        asDeployer();
        address t = launch(address(new RoleFreezeTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(deployer, t, abi.encodeWithSignature("pause()"));
        noExit(t, got / 2);
    }

    function test_RoleMintTrap() public {
        asDeployer();
        address t = launch(address(new RoleMintTrap()));
        uint256 got = mustBuy(alice, t);
        mintAndDump(t, abi.encodeWithSignature("mint(address,uint256)", deployer, 10_000_000_000 ether), got);
    }

    function test_TradingToggleTrap() public {
        asDeployer();
        address t = launch(address(new TradingToggleTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        mustCall(deployer, t, abi.encodeWithSignature("setTradingEnabled(bool)", false));
        noExit(t, got / 2);
    }

    // An EIP-1967 proxy: the admin swaps in an implementation that blocks sells.
    function test_UpgradeToHoneypotTrap() public {
        asDeployer();
        address t = launch(address(new UpgradeToHoneypotTrap()));
        uint256 got = mustBuy(alice, t);
        mustSell(alice, t, got / 2);
        address bad = address(new UpgradeToHoneypotBadLogic());
        require(!callAs(bob, t, abi.encodeWithSignature("upgradeTo(address)", bad)), "only the admin may upgrade");
        mustCall(deployer, t, abi.encodeWithSignature("upgradeTo(address)", bad));
        noExit(t, got / 2);
    }
}
