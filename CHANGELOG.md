# Changelog

## 0.1.0 (2026-11-18)

First public release. The tokens come from ChainK9's private test set, in use since October 2026.

- First release: labelled trap, risky, clean and info-only token fixtures for BNB Smart Chain,
  each with a Foundry fork test that proves its label (`test/`).
- `manifest.json` with class, mechanism, owner action, reveal and expected verdict per token.
- Three block-count tokens: `BlockDeadlineHoneypotTrap`, `BlockTaxRampTrap` and the control
  `BlockCooldownToken`, written for 3 s blocks and now running at 0.45 s.
- `UpgradeToHoneypotTrap`: an EIP-1967 proxy whose admin upgrades to a sell-blocking implementation.
- `score.mjs`: scores any self-hosted detector on a local fork and prints a confusion matrix.
  `--release public` deploys only the public tokens.
- `script/DeployTestnet.s.sol` deploys the public tokens on BSC testnet (chain id 97) as a demo.
- A held-out set of newer in-the-wild tricks is kept private and will move into the public set
  gradually; each move is listed here.
