# freelunch ⚡

*"The free lunch is over" — so said Herb Sutter in 2005: no more speed for free, go parallel. This plugin takes the deal literally.*

A Claude Code plugin (distributed via the [`tokenmaxxxer` marketplace](../README.md), one directory up) that estimates a task's *width* — its count of independently-producible deliverable units — before doing anything else, then branches: a lean solo pass with no subagents for narrow tasks (width 5 or fewer), or a lean fan-out of concurrent background Sonnet agents for wide ones. It optimizes wall-clock time only, skips quality-verification passes by design, and every rule in it survived an elimination benchmark — the ones that didn't are banned inside the plugin itself, with the numbers.

## Measured results

Ablation benchmark of the shipped v0.2.0 plugin: 18 tasks (narrow to wide, ten domains), plugin ON vs OFF, two reps each, 72 headless runs, quality scored by test scripts the agent can neither see nor modify.

- **1.50x geometric-mean wall-clock speedup** (median 1.59x); 15 of 18 tasks faster, paired Wilcoxon p = 1.1×10⁻⁸.
- **Quality exactly tied**: 630/632 objective checks pass in both arms — the same two failures on each side.
- **Cheaper, not just faster**: $30.48 total vs the baseline's $39.49 — lean solo saves more tokens on narrow tasks than fan-out spends on wide ones.

| Task | OFF | ON | Speedup |
|---|---|---|---|
| xxl-onefile-py (~1500-line single file) | 251s | 100s | 2.50x |
| med-cli | 41s | 20s | 2.00x |
| med-site (16 pages, fan-out) | 168s | 87s | 1.94x |
| refactor (width 1, solo) | 63s | 34s | 1.84x |
| lg-site (30 pages, 6-worker fan-out) | 245s | 134s | 1.83x |
| dom-infra (the one loss) | 14.6s | 17.3s | 0.85x |

The one loss is a 15-second task where reading the directive costs more than the solo branch saves. Note that narrow tasks win without any parallelism: the gain there is ceremony removal alone (no self-verification, no re-reading, deliver immediately), a task-independent saving of roughly 20 seconds.

Tested and rejected along the way (kept as in-directive bans):

- Unconditional fan-out (the v1 policy): median 0.96x across the suite — parallel dispatch below ~5 units of width loses its own overhead.
- Pre-racing every chunk with twin workers: slow chunks were slow in both twins (correlated tails), and doubled launch cost.
- Splitting fragments below ~50 output lines: 12-way was no faster than 8-way — agent spin-up dominates small pieces.
- Sub-file splitting in general: symbol-boundary and 250-line-cap cuts both lost to a solo pass at every file size tested, up to ~1500 lines.
- Haiku workers: identical 12-worker fan-out took 78s on Haiku vs 21s on Sonnet — per-request latency dominates, "smaller = faster" is false here.

## How it works

- `hooks/freelunch.sh` — `UserPromptSubmit` hook that injects the forcing directive into context on every prompt.
- `agents/freelunch-worker.md` — Sonnet-pinned worker agent that finishes one chunk with no verification pass.
- `workflows/site-fanout.js`, `workflows/code-fanout.js` — reusable fan-out scripts; dispatch passes only compact per-task specs via `args`, prompt templates and contracts live in the script.

The directive's core rules (v2, width-conditional):

1. Width estimate first: count independently-producible deliverable units in the task. Units that share state, an interface, or a contract count as ONE, not several. This is a tally, not an analysis — one short paragraph, then decide. Research tasks (the deliverable is gathered information, not files) count independent search angles instead of the single final report, gated so quick lookups stay solo; their integration step allows one semantic synthesis pass (v0.2.2, smoke-tested but not yet benchmarked).
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
/plugin marketplace add tokenmaxxxer/claude-plugins
/plugin install freelunch@tokenmaxxxer
```

(or from a shell: `claude plugin marketplace add tokenmaxxxer/claude-plugins && claude plugin install freelunch@tokenmaxxxer`)

**VSCode extension only** — the extension's chat does not support `/plugin` commands, so use the installer, which finds the CLI bundled inside the extension and runs the real install through it:

```
git clone https://github.com/tokenmaxxxer/claude-plugins.git
cd claude-plugins && ./install.sh   # repo-root installer: installs the whole stack via the tokenmaxxxer-env bundle
```

Then reload the VSCode window. The installer prefers a PATH `claude`, then the extension's bundled CLI, and as a last resort writes `~/.claude/settings.json` directly (backing up the original). Idempotent — safe to re-run.

## Temporarily disable

```
export FREELUNCH_OFF=1   # hook injects nothing
```

## Caveats

- Skipping verification is by design. On the benchmark it cost nothing measurable — but every suite task's pass rate sits near ceiling in both arms, so that is evidence from tasks precise enough to one-pass, not a general license. When a contract is wrong, seam bugs ship (one duplicated `</html>` did). Turn the plugin off for work where you need to trust the result.
- Width, not task size, drives the branch: a long but coupled task (e.g. a refactor touching one call graph) counts as narrow and runs lean solo; a short but decomposable task (many independent files) counts as wide and fans out.
- At the largest width tested (~30 independent units), early validation data showed v1's unconditional fan-out beating v2's fan-out path — but the 72-run sweep of the shipped plugin failed to reproduce that deficit (v2 134s vs v1's 130s, within this task's run-to-run spread). Treat high-width tuning as a variance question needing more repetitions, not a measured gap.
- The width branch runs on the model's own width tally, not on anyone's label. At the margin they can disagree: in the sweep, two tasks the suite labeled width 6 were counted narrower by the model and ran solo — both still matched or beat baseline.

---

v0.2.2 — by Jung Jiwon & Lee Jongkwan.
