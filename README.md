# bsc-honeypot-benchmark

Fake scam tokens for BNB Smart Chain, made for testing token scanners. Each token copies one trick
that real scams use: you can buy but not sell, a sell tax that jumps to 95%, an owner who can switch
off trading or upgrade the token into a honeypot. A test proves that every trick really works. Point
your scanner, wallet warning or trading bot at them and see which ones it catches, and whether it
wrongly flags the honest ones.

There are 47 tokens: 37 with a hidden trick, 4 honest controls, and 6 that only carry facts a scanner
may report. They run on a local copy of BSC or on BSC testnet. They refuse to deploy on mainnet, so
nobody's real money is involved.

The tokens have been ChainK9's internal test set since October 2026, used to test every check in its
engine. This repo makes them public, with tests that prove each trick, a scorer and a testnet deploy
script.

Made by [ChainK9](https://chaink9.com), which checks tokens by actually buying and selling them on a
copy of the chain. Sibling tools: [bsc-block-time](https://github.com/ChainK9/bsc-block-time) and
[bsc-lp-lock-checker](https://github.com/ChainK9/bsc-lp-lock-checker).

## Why

People who build token scanners rarely have an answer key. Which tokens are really traps, and how
do you know? Here every label is backed by a test that runs the trick. `test_HoneypotToken` buys,
tries to sell, and requires the sell to fail. An honest control token must buy and sell normally. If
a label were wrong, its test would fail.

## Who uses it, and how

- **People building token scanners, wallet warnings or launchpad filters.** Point `score.mjs` at
  your detector and run it in CI. A change that stops catching a trap, or starts flagging a clean
  control, shows up as a changed number in the matrix before it reaches users.
- **AI trading agents and bots.** Before an agent is allowed to buy on its own, check that its
  safety gate says `danger` on the traps and `ok` on the controls. It's the same run, with your
  agent's check as the detector.
- **Auditors and security researchers.** Each token is a small, readable example of one trick with
  a test that proves what it does. They're useful as reference cases, for training, and for writing
  detection rules.
- **Researchers.** Labels that are executable claims, not opinions, so results can be reproduced and
  compared across tools.
- **Anyone learning how honeypots work.** The public tokens are on BSC testnet (see below). Buy one
  with test BNB in MetaMask, try to sell, and watch it fail, with no real money at risk.

## What is in it

The public set has 47 tokens (counts come from `manifest.json`): **12 traps, 25 risky, 4 controls,
6 info-only**.

| Class | Meaning | Expected verdict |
|---|---|---|
| `trap` | Harm needs no one to act: a holder cannot exit, is taxed hard, or loses tokens through the token's own logic | danger |
| `risky` | Harm needs the owner or a role to act, or is bounded friction (limits, 30% taxes, cooldowns) | caution |
| `clean` | Real controls: rules exist but a holder can always exit | ok |
| `info` | Facts a detector may report (owner type, proxy admin, selfdestruct), not scored | none |

`manifest.json` has one entry per token: `id`, `class`, `release`, `mechanism`, `owner_action`,
`reveal` (what action shows the behaviour: `sell`, `second-sell`, `sell-after-time`,
`sell-after-blocks`, `owner-call-then-sell`, `buy`, `repeat-buy`, `transfer`, `read`), `expected`,
`scored` and `note`.

Three tokens count rules in blocks: `BlockDeadlineHoneypotTrap`, `BlockTaxRampTrap` and the control
`BlockCooldownToken`. They were written for 3 s blocks. BSC now makes a block every 0.45 s, so
28,800 blocks is 3 h 36 m, not a day. The tests move block number and clock together
(`bscSkip` in `test/Base.sol`).

A held-out set of newer in-the-wild tricks is kept private so detectors can't be tuned to the
answers; it moves into the public set gradually (see CHANGELOG). We can score a self-hosted
detector on it on request.

## Quick start

You need [Foundry](https://book.getfoundry.sh/) and Node 20 or newer. Use any BSC RPC; a public
node works because tests fork the latest block.

```bash
export BSC_RPC=https://bsc-rpc.publicnode.com   # or your own node

forge build
forge test --fork-url $BSC_RPC     # every label, proven (about 10 s)
node --test                        # offline checks: manifest, tests and scorer math
```

Without a BSC fork, `forge test` skips every test, so it stays green anywhere.

### Score your detector

`score.mjs` starts its own Anvil on a free port, forks the finalized BSC block, deploys every
scored token with 10 BNB of PancakeSwap V2 liquidity, and runs your command once per token. The
chain is reverted between tokens.

```bash
node score.mjs --fork-url $BSC_RPC \
  --detector "my-tool --rpc {rpc} {token} {pair}"   # add --release public, --json
```

`{rpc}` is the local Anvil URL, `{token}` the token address and `{pair}` its V2 pair. Your command
has 120 s per token and must print a last line like `{"verdict":"danger"}`, with the verdict one of
`danger`, `caution` or `ok`. Anything else counts as `error`. The chain id stays 56, so detectors
that choose their DEX by chain id pick PancakeSwap.

It prints a confusion matrix of expected class against verdict, and three rates:

- **catch**: traps called `danger`
- **flag**: traps and risky tokens called `danger` or `caution`
- **false alarm**: clean controls called `danger` or `caution`

Try the baseline first: `examples/always-ok.mjs` says `ok` to everything, so every token lands in
the `ok` column and all three rates are 0.

Anvil is found through the `ANVIL` variable, then `PATH`, then `~/.foundry/bin`. RPC URLs are
cut to `scheme://host` in all output.

## Try them on BSC testnet

These tokens are deliberately broken. They exist only on testnet, with test BNB. Never deploy them
on mainnet: bots buy new tokens within seconds and real people lose real money.

The public tokens go on BSC testnet (Chapel, chain id 97) so you can try them in MetaMask
against PancakeSwap's testnet router. The addresses appear in the table below once they are deployed. Each has 0.005 tBNB of liquidity. Token names are
the ones in `src/`; `deployments/bsc-testnet.json` maps each one to its `CK9T<n>` symbol, a label
(`ChainK9 Trap #<n>: <mechanism>`), its token and its pair. The numbering follows `manifest.json`
order, which never changes.

| # | Token | Address | Pair |
|---|---|---|---|
| | | | |

_Not deployed yet. The table is filled once the testnet deployment runs._

To deploy your own copy, use a testnet-only wallet. Import its key into a keystore once (`cast
wallet import` asks for the key interactively; never put a key on the command line or in a file
here), then run:

```bash
cast wallet import ck9-testnet --interactive
forge script script/DeployTestnet.s.sol \
  --rpc-url https://bsc-testnet-rpc.publicnode.com \
  --account ck9-testnet --broadcast
```

The script reverts unless the chain id is 97. A full run sends about 190M gas and 47 x 0.005 tBNB of
liquidity: have about 0.35 tBNB in the wallet. Transaction hashes land in
`broadcast/DeployTestnet.s.sol/97/run-latest.json`. `script/DeployTestnet.s.sol` is generated:
run `node scripts/gen-deploy-testnet.mjs` after changing the manifest.

## Honest limits

- Hosted scanners such as GoPlus and honeypot.is cannot be scored. They cannot see tokens that
  exist only on a local fork, and they do not support a BSC testnet to deploy to instead.
- Tokens that need a V3 or V4 pool, or EIP-7702 account state, are marked `scored: false` in the
  manifest with the reason; the launch helpers only build V2 pools. Their tests still prove the
  behaviour.
- The labels are judgments. `expected` records what a good detector should say; reasonable people
  could grade a few tokens one step differently. Open an issue if you disagree.
- Public RPC nodes are not archive nodes. The scorer forks the finalized block, which they serve
  for the length of a run, but an old block number will not work.
- The guard in `FixtureERC20` (a sentinel address, waived only on BSC testnet) only stops drop-in
  deployment on mainnet (see [SECURITY.md](SECURITY.md)). These
  are test fixtures: never deploy them on a live network.
- `SelfDestructTrap` is not executed by its test: Foundry's EVM crashes on selfdestruct in a
  fork. The test checks the owner gate and the dispatcher entry instead.

## Roadmap

- New traps modelled on tokens seen in the wild, each with its test and manifest entry, added
  every week from the held-out set.
- Score the unscored tokens: V3 and Uniswap V4 launch helpers, then EIP-7702 state.
- Bonding-curve traps before graduation (four.meme style).
- More block-count traps: lock and vesting releases counted in blocks, anti-bot windows.
- Scorer adapters for other self-hosted detectors, with a results table that names the detector
  version and fork block.

## License

MIT. See [LICENSE](LICENSE) and [CHANGELOG](CHANGELOG.md).
