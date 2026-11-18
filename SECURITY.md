# Security

## Dual use

This repository contains working honeypot and trap tokens. They are test fixtures for checking
detectors, and the patterns in them are already widely documented. Two things limit misuse, and
neither is a real barrier:

- Every token's constructor requires code at a sentinel address (`LOCAL_FORK_ONLY` in
  `src/FixtureERC20.sol`) that no real chain has, so a token deployed as-is on mainnet reverts.
  BSC testnet (chain id 97, test BNB) is the one exception, for the public demo deployment. Tests and `score.mjs` put code there on their own local fork.
- `score.mjs` only deploys to an Anvil it started itself.

The guard only stops drop-in deployment. Anyone can delete one line of Solidity. Do not rely on
it as protection, and do not deploy these tokens on a live network.

## Reporting

- A bug in the tests or the scorer, or a token whose label is wrong: open an issue.
- Anything you would rather not post publicly: email hello@chaink9.com.

Never put RPC URLs with API keys in issues, logs or pull requests.
