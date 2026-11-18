// A detector that never sees anything: the baseline for score.mjs. Every trap lands in the "ok"
// column and the controls show no false alarms, which proves the scoring math on a known detector.
// Usage: node score.mjs --fork-url $BSC_RPC --detector "node examples/always-ok.mjs {rpc} {token} {pair}"
console.log(JSON.stringify({ verdict: "ok" }));
