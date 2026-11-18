// Offline checks, no RPC needed: node --test test/
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { render } from "../scripts/gen-deploy-testnet.mjs";
import { confusion, rates, parseVerdict, redact } from "../score.mjs";

const read = (p) => readFileSync(new URL("../" + p, import.meta.url), "utf8");
const manifest = JSON.parse(read("manifest.json"));
const testFiles = (dir) =>
  readdirSync(new URL("../" + dir, import.meta.url), { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? testFiles(dir + e.name + "/") : e.name.endsWith(".t.sol") ? [dir + e.name] : []);
const testSources = testFiles("test/").map(read).join("\n");

test("confusion matrix and rates on a known detector", () => {
  const m = confusion([
    { class: "trap", verdict: "danger" },
    { class: "trap", verdict: "ok" },
    { class: "trap", verdict: "error" },
    { class: "risky", verdict: "caution" },
    { class: "risky", verdict: "ok" },
    { class: "clean", verdict: "ok" },
    { class: "clean", verdict: "caution" },
  ]);
  assert.deepEqual(m.trap, { danger: 1, caution: 0, ok: 1, error: 1 });
  assert.deepEqual(m.risky, { danger: 0, caution: 1, ok: 1, error: 0 });
  const r = rates(m);
  assert.equal(r.catch, 1 / 3); // 1 of 3 traps called danger
  assert.equal(r.flag, 2 / 5); // 1 trap + 1 risky flagged out of 3 + 2
  assert.equal(r.false_alarm, 1 / 2);
});

test("rates are null when a class is empty", () => {
  assert.deepEqual(rates(confusion([])), { catch: null, flag: null, false_alarm: null });
});

test("always-ok puts everything in the ok column", () => {
  const rows = manifest.filter((t) => t.scored).map((t) => ({ class: t.class, verdict: "ok" }));
  const r = rates(confusion(rows));
  assert.deepEqual(r, { catch: 0, flag: 0, false_alarm: 0 });
});

test("verdict parsing takes the last line and rejects junk", () => {
  assert.equal(parseVerdict('log line\n{"verdict":"danger"}\n'), "danger");
  assert.equal(parseVerdict("not json"), "error");
  assert.equal(parseVerdict('{"verdict":"maybe"}'), "error");
  assert.equal(parseVerdict(""), "error");
});

test("redact cuts URLs down to scheme://host", () => {
  const url = "https://node.example.com/v1/SECRETKEY";
  assert.equal(redact(`failed to fetch ${url}: 401`, url), "failed to fetch https://node.example.com: 401");
  assert.equal(redact("see https://a.example.org/x?k=1 now"), "see https://a.example.org now");
});

test("every token in src/ has a manifest entry and a test_<Id>", () => {
  const ids = readdirSync(new URL("../src/", import.meta.url))
    .filter((f) => f.endsWith(".sol") && !["FixtureERC20.sol", "FixtureOwnable.sol"].includes(f))
    .map((f) => f.replace(".sol", ""));
  const inManifest = new Set(manifest.map((t) => t.id));
  for (const id of ids) {
    assert.ok(inManifest.has(id), `${id} has no manifest entry`);
    assert.match(testSources, new RegExp(`function test_${id}\\(`), `${id} has no test_${id}`);
  }
  for (const id of inManifest) assert.ok(ids.includes(id), `manifest entry ${id} has no src/${id}.sol`);
  assert.equal(inManifest.size, manifest.length, "duplicate manifest id");
});

test("manifest fields are valid", () => {
  const classes = ["trap", "risky", "clean", "info"];
  const reveals = ["sell", "second-sell", "sell-after-time", "sell-after-blocks", "owner-call-then-sell", "buy", "repeat-buy", "transfer", "read"];
  for (const t of manifest) {
    assert.ok(classes.includes(t.class), t.id);
    assert.ok(reveals.includes(t.reveal), `${t.id} reveal ${t.reveal}`);
    assert.ok(["danger", "caution", "ok"].includes(t.expected), t.id);
    assert.equal(typeof t.scored, "boolean", t.id);
    assert.ok(["public", "holdout"].includes(t.release), `${t.id} release`);
    if (t.class === "info") assert.equal(t.scored, false, t.id);
    if (!t.scored && t.class !== "info") assert.match(t.note, /Not scored/, `${t.id} needs a reason`);
  }
});

test("the scorer and the Solidity guard agree on the sentinel address", () => {
  const scorer = read("score.mjs").match(/LOCAL_FORK_ONLY = "0x([0-9a-f]{40})"/)[1];
  assert.ok(read("test/Guard.t.sol").includes(`hex"${scorer}"`));
});

test("no RPC URLs or secrets are committed", () => {
  for (const f of ["README.md", "score.mjs", "manifest.json", ".github/workflows/ci.yml"]) {
    let text = "";
    try { text = read(f); } catch { continue; }
    assert.doesNotMatch(text, /https?:\/\/[^\s"']*(?:\/[a-zA-Z0-9_-]{24,}|[?&]key=)/, `${f} looks like it holds a keyed URL`);
  }
});

test("public test files never import a holdout token", () => {
  const holdout = manifest.filter((t) => t.release === "holdout").map((t) => t.id);
  for (const f of testFiles("test/").filter((f) => !f.startsWith("test/holdout/")))
    for (const id of holdout) assert.ok(!read(f).includes(id), `${f} mentions holdout token ${id}`);
});

test("README class counts match the public part of the manifest", () => {
  const pub = manifest.filter((t) => t.release === "public");
  const n = (c) => pub.filter((t) => t.class === c).length;
  const want = `${pub.length} tokens`;
  const readme = read("README.md");
  assert.ok(readme.includes(want), "README should say " + want);
  assert.ok(readme.includes(`${n("trap")} traps, ${n("risky")} risky, ${n("clean")} controls`));
});

test("script/DeployTestnet.s.sol is generated from the manifest", () => {
  assert.equal(read("script/DeployTestnet.s.sol"), render(manifest), "run: node scripts/gen-deploy-testnet.mjs");
});

test("block.chainid appears only in 97 checks", () => {
  for (const f of readdirSync(new URL("../src/", import.meta.url)))
    for (const line of read("src/" + f).split("\n"))
      if (line.includes("block.chainid")) assert.ok(line.includes("== 97"), `${f}: ${line.trim()}`);
});
