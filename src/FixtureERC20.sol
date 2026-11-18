// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

/// @notice Minimal ERC-20 base for the trap-token fixtures. TEST FIXTURE: only ever
/// deployed on local forks or BSC testnet, never on mainnet.
/// It mints the whole supply to the deployer and creates its V2 pair against the chain's
/// wrapped coin (PancakeSwap V2 / WBNB on BSC) up front, so traps can recognise sells (`to == pair`) and buys (`from == pair`).
/// Traps override _update and call super._update to add their trick.
abstract contract FixtureERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public pair;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Dual-use guard: this address never has code on a real chain. Tests etch it and the
    // scorer sets it on its own local fork, so a drop-in deployment on mainnet reverts. BSC
    // testnet (chain id 97, test BNB only) is the one other place these tokens may live.
    address public constant LOCAL_FORK_ONLY = address(uint160(uint256(keccak256("bsc-honeypot-benchmark: local fork only"))));

    constructor(string memory name_, string memory symbol_) {
        require(block.chainid == 97 || LOCAL_FORK_ONLY.code.length != 0, "local fork or BSC testnet only");
        name = name_;
        symbol = symbol_;
        (address factory, address wrapped) = _v2Market();
        pair = IV2Factory(factory).createPair(address(this), wrapped);
        _update(address(0), msg.sender, 1_000_000_000 ether);
    }

    /// PancakeSwap V2 factory and WBNB: BSC testnet when chain id is 97, otherwise BSC mainnet.
    function _v2Market() private view returns (address factory, address wrapped) {
        if (block.chainid == 97) return (0x6725F303b657a9451d8BA641348b6761A6CC7a17, 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd);
        return (0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73, 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _update(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _update(from, to, amount);
        return true;
    }

    /// Moves balances (from == 0 mints, to == 0 burns) and emits Transfer.
    function _update(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            totalSupply += amount;
        } else {
            require(balanceOf[from] >= amount, "balance");
            unchecked {
                balanceOf[from] -= amount;
            }
        }
        if (to == address(0)) {
            totalSupply -= amount;
        } else {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}
