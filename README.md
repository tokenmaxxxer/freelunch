# freelunch ⚡

*"The free lunch is over" — so said Herb Sutter in 2005: no more speed for free, go parallel. This plugin takes the deal literally.*

A Claude Code plugin (this repo is its marketplace, `freelunch`; the plugin lives in [freelunch/](freelunch/)) that estimates a task's *width* — its count of independently-producible deliverable units — before doing anything else, then branches: a lean solo pass with no subagents for narrow tasks (width 5 or fewer), or a lean fan-out of concurrent background Sonnet agents for wide ones. It optimizes wall-clock time only, skips quality-verification passes by design, and every rule in it survived an elimination benchmark — the ones that didn't are banned inside the plugin itself, with the numbers.

## Measured results

Same task, same model (Sonnet), same machine:

| Task | Single agent | freelunch | Speedup |
|---|---|---|---|
| 4-page static site + shared CSS | 184s | 43s | 4.3x |
| 11-file Python CLI (cross-module imports, pytest) | 185s | 49s | 3.8x |

The Python build passed all 24 of its tests and a live CLI smoke test on first run, with zero integration fixes — six workers coded against an up-front interface contract without ever seeing each other's files.

Tested and rejected along the way (kept as in-directive bans):

- Pre-racing every chunk with twin workers: 72s vs 57s — slow chunks were slow in both twins (correlated tails), and doubled launch cost.
- Splitting fragments below ~50 output lines: 12-way was no faster than 8-way — agent spin-up dominates small pieces.
- Haiku workers: identical 12-worker fan-out took 78s on Haiku vs 21s on Sonnet — per-request latency dominates, "smaller = faster" is false here.

## How it works

- `freelunch/hooks/freelunch.sh` — `UserPromptSubmit` hook that injects the forcing directive into context on every prompt.
- `freelunch/agents/freelunch-worker.md` — Sonnet-pinned worker agent that finishes one chunk with no verification pass.
- `freelunch/workflows/site-fanout.js`, `freelunch/workflows/code-fanout.js` — reusable fan-out scripts; dispatch passes only compact per-task specs via `args`, prompt templates and contracts live in the script.

The directive's core rules (v2, width-conditional):

1. Width estimate first: count independently-producible deliverable units in the task. Units that share state, an interface, or a contract count as ONE, not several. This is a tally, not an analysis — one short paragraph, then decide.
2. Width 5 or fewer -> **lean solo**: no subagents, single pass in the main session, no self-verification, no re-reading finished units. Deliver as soon as the work is done.
3. Width over 5 -> **lean fan-out**: partition by file/unit ownership into roughly equal-duration groups (floor: ~50 lines of expected output each), never more groups than the width count.
4. Every fan-out worker runs on Sonnet, launched in the background in a single batch — never synchronous.
5. Worker prompts are minimal: owned path(s), requirements, and the frozen shared contract. Workers are told explicitly to skip verification.
6. Fan-outs of 4+ workers dispatch via a Workflow script built from a shared contract template, so the contract is emitted once.
7. Hedging is reactive only — a straggler at ~2x median finish time gets one replacement racer, never a pre-race of every chunk.
8. Integration is mechanical assembly: each group's output goes to its slot, no rewriting, no cross-checking workers against each other, no review pass, under either mode.

Removed from v1 as refuted by the benchmark: the minimum-3-agents mandate, unconditional fan-out regardless of task width, and sub-file fragment splitting as a default technique.

## Install

**With the `claude` CLI** — no clone needed, inside any CLI session:

```
/plugin marketplace add tokenmaxxxer/freelunch
/plugin install freelunch@freelunch
```

(or from a shell: `claude plugin marketplace add tokenmaxxxer/freelunch && claude plugin install freelunch@freelunch`)

**VSCode extension only** — the extension's chat does not support `/plugin` commands, so use the installer, which finds the CLI bundled inside the extension and runs the real install through it:

```
git clone https://github.com/tokenmaxxxer/freelunch.git
cd freelunch && ./install.sh
```

Then reload the VSCode window. The installer prefers a PATH `claude`, then the extension's bundled CLI, and as a last resort writes `~/.claude/settings.json` directly (backing up the original). Idempotent — safe to re-run.

## Temporarily disable

```
export FREELUNCH_OFF=1   # hook injects nothing
```

## Caveats

- Skipping verification is by design. It cost nothing on the benchmarks above because the specs were precise; when a contract is wrong, seam bugs ship (one duplicated `</html>` did). Turn the plugin off for work where you need to trust the result.
- Width, not task size, drives the branch: a long but coupled task (e.g. a refactor touching one call graph) counts as narrow and runs lean solo; a short but decomposable task (many independent files) counts as wide and fans out.
- At the largest width tested so far (~30 independent units), v1's older unconditional fan-out still ran 1.57x faster than v2's fan-out path on the same task. The width threshold and lean-fan-out tuning at the high end of the range are provisional and may need revisiting as more data comes in — see `experiments/protocols/v2.md` and `docs/paper/04-results.md` (section 6.3) for the underlying measurements.

---

v0.2.0 — by Jung Jiwon & Lee Jongkwan.
