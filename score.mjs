#!/usr/bin/env node
// Scores a token detector against the trap-token set. No dependencies, Node >= 20.
//
//   node score.mjs --fork-url $BSC_RPC --detector "my-tool --rpc {rpc} {token} {pair}" [--release public] [--json]
//   --release public deploys only the public tokens (default: every scored token).
//
// It starts its own anvil on a free port, forks the finalized BSC block, deploys every scored
// token with liquidity, then for each token runs the detector command and reverts the chain.
// The detector must print a last line like {"verdict":"danger"} (danger | caution | ok).
// Run `forge build` first: the token bytecode comes from out/.

import { spawn, spawnSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { createServer } from "node:net";
import { homedir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = dirname(fileURLToPath(import.meta.url));
const DEPLOYER = "0x00000000000000000000000000000000000C4A90";
const ROUTER = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
const VERDICTS = ["danger", "caution", "ok", "error"];
const CLASSES = ["trap", "risky", "clean"];
const DETECTOR_TIMEOUT_MS = 120_000;

// Last 20 bytes of keccak256("bsc-honeypot-benchmark: local fork only"). Node has no keccak, so it is written
// out; test/Guard.t.sol and test/score.test.mjs check it against the Solidity constant.
const LOCAL_FORK_ONLY = "0x61e88edbced58c97f3eba2c7bbb7a06ffd75aeaf";

// ---------- scoring math (exported for tests) ----------

/** results: [{class, verdict}] -> {trap: {danger, caution, ok, error}, risky: {...}, clean: {...}} */
export function confusion(results) {
  const m = Object.fromEntries(CLASSES.map((c) => [c, Object.fromEntries(VERDICTS.map((v) => [v, 0]))]));
  for (const r of results) if (m[r.class]) m[r.class][VERDICTS.includes(r.verdict) ? r.verdict : "error"]++;
  return m;
}

const ratio = (n, d) => (d === 0 ? null : n / d);
const total = (row) => VERDICTS.reduce((s, v) => s + row[v], 0);

/** catch: traps called danger. flag: traps and risky tokens called danger or caution.
 *  false alarm: clean tokens called danger or caution. null when the denominator is 0. */
export function rates(m) {
  const flagged = (row) => row.danger + row.caution;
  return {
    catch: ratio(m.trap.danger, total(m.trap)),
    flag: ratio(flagged(m.trap) + flagged(m.risky), total(m.trap) + total(m.risky)),
    false_alarm: ratio(flagged(m.clean), total(m.clean)),
  };
}

export function parseVerdict(stdout) {
  const last = stdout.trim().split(/\r?\n/).filter(Boolean).pop();
  try {
    const v = JSON.parse(last).verdict;
    return ["danger", "caution", "ok"].includes(v) ? v : "error";
  } catch {
    return "error";
  }
}

/** Cut every URL down to scheme://host so API keys in paths never reach the output. */
export function redact(text, ...secrets) {
  let s = String(text);
  for (const x of secrets) if (x) s = s.split(x).join(new URL(x).origin);
  return s.replace(/(?:https?|wss?):\/\/[^\s"'<>/:?#]+(?::\d+)?(?:[/?#][^\s"'<>]*)?/g, (u) => new URL(u).origin);
}

function table(m, r) {
  const pct = (x) => (x === null ? "n/a" : (x * 100).toFixed(1) + "%");
  const head = ["expected \\ verdict", ...VERDICTS, "total"];
  const lines = [head, ...CLASSES.map((c) => [c, ...VERDICTS.map((v) => m[c][v]), total(m[c])])];
  const w = head.map((_, i) => Math.max(...lines.map((l) => String(l[i]).length)));
  const out = lines.map((l) => l.map((c, i) => String(c).padEnd(w[i])).join("  "));
  out.push("", `catch       ${pct(r.catch)}   (traps called danger)`);
  out.push(`flag        ${pct(r.flag)}   (traps and risky tokens called danger or caution)`);
  out.push(`false alarm ${pct(r.false_alarm)}   (clean controls called danger or caution)`);
  return out.join("\n");
}

// ---------- anvil and JSON-RPC ----------

function findAnvil() {
  const exe = process.platform === "win32" ? "anvil.exe" : "anvil";
  const candidates = [process.env.ANVIL, "anvil", join(homedir(), ".foundry", "bin", exe)].filter(Boolean);
  for (const c of candidates) if (spawnSync(c, ["--version"]).status === 0) return c;
  throw new Error("anvil not found: set ANVIL, add it to PATH, or install Foundry (~/.foundry/bin)");
}

const freePort = () =>
  new Promise((resolve, reject) => {
    const s = createServer().once("error", reject).listen(0, "127.0.0.1", () => {
      const { port } = s.address();
      s.close(() => resolve(port));
    });
  });

async function rpc(url, method, params = []) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const body = await res.json();
  if (body.error) throw new Error(`${method}: ${body.error.message}`);
  return body.result;
}

const pad = (hex) => hex.replace(/^0x/, "").toLowerCase().padStart(64, "0");
const hexN = (n) => "0x" + BigInt(n).toString(16);

async function startAnvil(forkUrl) {
  const anvil = findAnvil();
  const block = (await rpc(forkUrl, "eth_getBlockByNumber", ["finalized", false])).number;
  const port = await freePort();
  const child = spawn(
    anvil,
    ["--fork-url", forkUrl, "--fork-block-number", String(parseInt(block, 16)), "--port", String(port), "--host", "127.0.0.1", "--silent"],
    { stdio: ["ignore", "ignore", "pipe"] },
  );
  let stderr = "";
  child.stderr.on("data", (d) => (stderr += d));
  let exited = false;
  child.on("exit", () => (exited = true));
  const url = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 120; i++) {
    if (exited) throw new Error("anvil exited: " + redact(stderr, forkUrl).slice(-300));
    try {
      const v = await rpc(url, "web3_clientVersion");
      // Never deploy to anything but the anvil this script just started.
      if (!String(v).startsWith("anvil")) throw new Error(`port ${port} is not anvil (${v}); refusing to deploy`);
      return { child, url, block: parseInt(block, 16) };
    } catch (e) {
      if (String(e.message).includes("refusing")) {
        child.kill();
        throw e;
      }
      await new Promise((r) => setTimeout(r, 500));
    }
  }
  child.kill();
  throw new Error("anvil did not start in 60 s");
}

// ---------- deployment ----------

async function send(url, tx) {
  const hash = await rpc(url, "eth_sendTransaction", [{ from: DEPLOYER, gas: "0x7a1200", ...tx }]);
  // Anvil mines a moment after eth_sendTransaction returns. Until then it asks the upstream node about
  // the hash, and some public nodes answer that with an error instead of null, so retry on both.
  let rc = null;
  for (let i = 0; i < 100 && !rc; i++) {
    rc = await rpc(url, "eth_getTransactionReceipt", [hash]).catch(() => null);
    if (!rc) await new Promise((r) => setTimeout(r, 50));
  }
  if (!rc) throw new Error("no receipt for " + (tx.to ?? "deploy"));
  if (rc.status !== "0x1") throw new Error(`transaction reverted (${tx.to ?? "deploy"})`);
  return rc;
}

async function deployWithLiquidity(url, id) {
  const art = JSON.parse(readFileSync(join(ROOT, "out", `${id}.sol`, `${id}.json`), "utf8"));
  const token = (await send(url, { data: art.bytecode.object })).contractAddress;
  const pair = "0x" + (await rpc(url, "eth_call", [{ to: token, data: "0xa8aa1b31" }, "latest"])).slice(-40);
  const bal = BigInt(await rpc(url, "eth_call", [{ to: token, data: "0x70a08231" + pad(DEPLOYER) }, "latest"]));
  const half = bal / 2n;
  await send(url, { to: token, data: "0x095ea7b3" + pad(ROUTER) + pad(hexN(half)) });
  // addLiquidityETH(token, half, 0, 0, deployer, far future) with 10 BNB: the same launch as the Foundry tests.
  const data = "0xf305d719" + pad(token) + pad(hexN(half)) + pad("0x0") + pad("0x0") + pad(DEPLOYER) + pad(hexN(4102444800));
  await send(url, { to: ROUTER, value: hexN(10n * 10n ** 18n), data });
  return { token, pair };
}

// ---------- detector ----------

function runDetector(template, { rpc: rpcUrl, token, pair }) {
  const cmd = template.replaceAll("{rpc}", rpcUrl).replaceAll("{token}", token).replaceAll("{pair}", pair);
  return new Promise((resolve) => {
    const child = spawn(cmd, { shell: true, stdio: ["ignore", "pipe", "ignore"] });
    let out = "";
    child.stdout.on("data", (d) => (out += d));
    const timer = setTimeout(() => {
      // shell: true leaves a shell between us and the detector, so kill the whole tree.
      if (process.platform === "win32") spawnSync("taskkill", ["/pid", String(child.pid), "/T", "/F"]);
      else child.kill("SIGKILL");
      resolve("error");
    }, DETECTOR_TIMEOUT_MS);
    child.on("close", () => {
      clearTimeout(timer);
      resolve(parseVerdict(out));
    });
    child.on("error", () => {
      clearTimeout(timer);
      resolve("error");
    });
  });
}

// ---------- main ----------

function parseArgs(argv) {
  const a = { json: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--json") a.json = true;
    else if (argv[i] === "--fork-url") a.forkUrl = argv[++i];
    else if (argv[i] === "--detector") a.detector = argv[++i];
    else if (argv[i] === "--release") a.release = argv[++i];
    else if (argv[i] === "--only") a.only = argv[++i].split(",");
    else throw new Error(`unknown argument ${argv[i]}`);
  }
  a.forkUrl ??= process.env.BSC_RPC;
  if (!a.forkUrl || !a.detector) throw new Error('usage: node score.mjs --fork-url $BSC_RPC --detector "tool --rpc {rpc} {token} {pair}" [--release public] [--json] [--only Id,Id]');
  return a;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const manifest = JSON.parse(readFileSync(join(ROOT, "manifest.json"), "utf8")).filter((t) => t.scored && (!args.only || args.only.includes(t.id)) && (!args.release || t.release === args.release));
  const missing = manifest.filter((t) => !existsSync(join(ROOT, "out", `${t.id}.sol`, `${t.id}.json`)));
  if (missing.length) throw new Error("run `forge build` first; no artifact for " + missing.map((t) => t.id).join(", "));

  const { child, url, block } = await startAnvil(args.forkUrl);
  try {
    await rpc(url, "anvil_setCode", [LOCAL_FORK_ONLY, "0x00"]);
    await rpc(url, "anvil_impersonateAccount", [DEPLOYER]);
    await rpc(url, "anvil_setBalance", [DEPLOYER, hexN(10_000n * 10n ** 18n)]);

    const deployed = [];
    for (const t of manifest) deployed.push({ ...t, ...(await deployWithLiquidity(url, t.id)) });

    const results = [];
    for (const t of deployed) {
      const snap = await rpc(url, "evm_snapshot");
      const verdict = await runDetector(args.detector, { rpc: url, token: t.token, pair: t.pair });
      await rpc(url, "evm_revert", [snap]);
      results.push({ id: t.id, class: t.class, expected: t.expected, verdict });
      if (!args.json) console.error(`${t.id.padEnd(30)} ${t.class.padEnd(6)} -> ${verdict}`);
    }
    const m = confusion(results);
    const r = rates(m);
    const fork = { host: new URL(args.forkUrl).origin, block };
    if (args.json) console.log(JSON.stringify({ fork, results, matrix: m, rates: r }, null, 2));
    else console.log(`\nfork ${fork.host} block ${block}, ${results.length} tokens\n\n${table(m, r)}`);
  } finally {
    child.kill();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((e) => {
    console.error("error: " + redact(e.message, process.env.BSC_RPC, process.argv[process.argv.indexOf("--fork-url") + 1]));
    process.exit(1);
  });
}
