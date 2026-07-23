# freelunch ⚡

*"The free lunch is over" — so said Herb Sutter in 2005: no more speed for free, go parallel. This plugin takes the deal literally.*

A Claude Code plugin (distributed via the [`tokenmaxxxer` marketplace](../README.md), one directory up) that freezes the task's shared contract, estimates its *width* — the count of independently-producible deliverable units given that frozen contract — and then branches: a lean solo pass for narrow tasks (width 2 or fewer, or tiny units), itself delegated to a single background worker unless the turn needs no repo tool call at all, or a lean fan-out of concurrent background Sonnet agents when width is 3+ with ~100+ expected lines per unit. It optimizes wall-clock time only, skips quality-verification passes by design, and every rule in it survived an elimination benchmark — the ones that didn't are banned inside the plugin itself, with the numbers.

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
- Sub-file splitting *as done in v1* (no frozen signatures, no packing): symbol-boundary and 250-line-cap cuts both lost to a solo pass at every file size tested, up to ~1500 lines. **Partially overturned in v2.4-2.5** — with each unit's export-signature line frozen verbatim in the contract and units packed to ~100-200 lines per worker, symbol-level fan-out won 2.7x at equal quality (see below). The v1-style naive cut stays banned.
- Haiku workers: identical 12-worker fan-out took 78s on Haiku vs 21s on Sonnet — per-request latency dominates, "smaller = faster" is false here.

## Observation vs enforcement

The `PreToolUse` observer logs every Agent/Task/Workflow dispatch and flags two
violations — a synchronous dispatch, and a worker on a model other than Sonnet.
**It only denies them when `FREELUNCH_ENFORCE=1` is set.** Without that variable
the violations are recorded to `~/.claude/freelunch-observe.jsonl` and the call
proceeds, so a session can drift from the directive with nothing in the
transcript to show for it. Set the variable to make the two rules binding:

```sh
export FREELUNCH_ENFORCE=1
```

Kill switch for both logging and enforcement: `FREELUNCH_OFF=1`.

## How it works

- `hooks/freelunch.sh` — `UserPromptSubmit` hook that injects the forcing directive into context on every prompt.
- `agents/freelunch-worker.md` — Sonnet-pinned worker agent that finishes one chunk with no verification pass.
- `workflows/site-fanout.js`, `workflows/code-fanout.js` — reusable fan-out scripts; dispatch passes only compact per-task specs via `args`, prompt templates and contracts live in the script.

The directive's core rules (v2.5, contract-first width-conditional):

1. Contract split, then width: first identify any shared contract (schema, interface, vocabulary, style guide) freezable upfront in roughly a page, then count independently-producible units ASSUMING it is frozen. Units merge only under non-freezable coupling: shared mutable state (the same *lines* — distinct self-contained symbols in one file count separately when each unit's export-signature line is frozen verbatim), sequential dependency, or an interface still being co-designed. Sharing a freezable contract is NOT a merge reason. Research tasks (the deliverable is gathered information, not files) count independent search angles instead of the single final report, gated so quick lookups stay solo; their integration step allows one semantic synthesis pass (v0.2.2, smoke-tested but not yet benchmarked).
2. Width 2 or fewer, or units too small to amortize dispatch -> **lean solo**: no subagents, single pass in the main session, no self-verification, no re-reading finished units. Deliver as soon as the work is done.
3. Width 3+ with ~100+ expected lines per unit -> **lean fan-out**: freeze the contract verbatim, then partition by file- or symbol-level ownership into roughly equal-duration groups packed to ~100-200 expected lines each, never more groups than the width count. Symbol-level groups are assembled by fixed-order concatenation and each such worker starts from its frozen export-signature line.
4. Every fan-out worker runs on Sonnet, launched in the background in a single batch — never synchronous. Workers on mechanical contract-pinned groups run at low reasoning effort; default effort where the unit needs judgment beyond the contract.
5. Worker prompts are minimal: owned path(s), requirements, and the frozen shared contract. Workers are told explicitly to skip verification.
6. Fan-outs of 4+ workers dispatch via a Workflow script built from a shared contract template, so the contract is emitted once.
7. Hedging is reactive only — a straggler at ~2x median finish time (or ~2x the dispatch estimate, for a single delegated worker) gets one liveness probe, then one replacement if it is looping rather than advancing; never a pre-race of every chunk. The probe reads progress, never the worker's output, and retries are capped at one.
8. Integration is mechanical assembly: each group's output goes to its slot, no rewriting, no cross-checking workers against each other, no review pass, under either mode.

Removed from v1 as refuted by the benchmark: the minimum-3-agents mandate, unconditional fan-out regardless of task width, and naive sub-file fragment splitting as a default technique.

## v2.3-v2.5 revisions (2026-07-20, workflow-harness A/Bs — not yet re-run through the headless suite)

- **v2.3 — solo-collapse fix.** The v2 width rules counted any shared contract as ONE unit and ignored per-unit volume, so exactly the tasks where fan-out pays most (multi-file deliverables over a freezable contract) routed solo. Routing probe, 12 ground-truth-labeled tasks x old/new directive (24 router agents): old misrouted 4 of 6 should-fan tasks to solo; new scored 12/12 with zero false fan-outs.
- **v2.4 — symbol-level width.** One worker per self-contained symbol within a file, mechanical concat assembly, vs a whole-module solo control; same frozen contract, judged by a 60-assert battery pre-registered before generation. 2.7x wall-clock at equal logic quality. The single observed failure class — a worker dropping the `export` keyword — is prevented by freezing each unit's signature line in the contract: zero seam defects across all subsequent signature-frozen runs (76 workers) vs 1/14 without.
- **v2.5 — packing and effort.** 7-arm sweep: 2-symbol groups matched 1-symbol wall-clock within run variance while spending 43% fewer tokens (per-worker fixed overhead ~23k tokens); 4-symbol groups keep saving tokens at ~+70% latency; low-effort workers on contract-pinned mechanical units ran 5x faster at equal quality (single run).
- **Mid-size scale check.** 12-file zero-dependency REST API (5 domains with cross-references, file-backed atomic persistence, bearer auth), contract ~90 lines — deliberately past the one-page guideline. 7 fan workers vs 1 solo agent, judged by a pre-registered 34-assert end-to-end test (boot, auth, validation, filters, kill-and-restart persistence): fan 47.8s vs solo 125.0s (2.6x), **both 34/34**, zero cross-worker integration defects on first boot. Token cost 4.4x. Untested still: genuinely multi-wave projects, brownfield repos, >15 files.

## Install

**With the `claude` CLI** — no clone needed, inside any CLI session:

```
/plugin marketplace add tokenmaxxxer/coding-agent-rulebook
/plugin install freelunch@tokenmaxxxer
```

(or from a shell: `claude plugin marketplace add tokenmaxxxer/coding-agent-rulebook && claude plugin install freelunch@tokenmaxxxer`)

**VSCode extension only** — the extension's chat does not support `/plugin` commands, so use the installer, which finds the CLI bundled inside the extension and runs the real install through it:

```
git clone https://github.com/tokenmaxxxer/coding-agent-rulebook.git
cd coding-agent-rulebook && ./install.sh   # repo-root installer: installs the whole stack via the tokenmaxxxer-env bundle
```

Then reload the VSCode window. The installer prefers a PATH `claude`, then the extension's bundled CLI, and as a last resort writes `~/.claude/settings.json` directly (backing up the original). Idempotent — safe to re-run.

## Telemetry & optional enforcement

A PreToolUse hook (`hooks/observe.sh`) logs every Agent/Task/Workflow dispatch to `~/.claude/freelunch-observe.jsonl` (override: `FREELUNCH_OBSERVE_LOG`), flagging the syntactically checkable rules — synchronous agent dispatch (`run_in_background: false`) and off-Sonnet workers (`non_sonnet_worker`: no `model: sonnet`, and not `subagent_type: freelunch-worker` with the model left unset; any agent type passes if it carries `model: sonnet`). Default is observe-only: nothing is ever blocked. With `FREELUNCH_ENFORCE=1` a flagged call is denied with a corrective reason and the model re-issues it corrected — semantically equivalent, no work lost (validated live for the background rule: deny → auto-retry background → task completed; the Sonnet rule ships unvalidated). Known blind spot: `agent()` calls inside a Workflow script are SDK-internal and don't pass through PreToolUse, so the Sonnet pin there rests on the scripts' own `model: A.model || 'sonnet'` default; only the Workflow dispatch itself is logged. `FREELUNCH_OFF=1` disables logging and enforcement along with everything else.

## Temporarily disable

```
export FREELUNCH_OFF=1   # hook injects nothing
```

## Caveats

- Skipping verification is by design. On the benchmark it cost nothing measurable — but every suite task's pass rate sits near ceiling in both arms, so that is evidence from tasks precise enough to one-pass, not a general license. When a contract is wrong, seam bugs ship (one duplicated `</html>` did). Turn the plugin off for work where you need to trust the result.
- Width, not task size, drives the branch: a long but coupled task (e.g. a refactor touching one call graph) counts as narrow and runs lean solo; a short but decomposable task (many independent files) counts as wide and fans out.
- At the largest width tested (~30 independent units), early validation data showed v1's unconditional fan-out beating v2's fan-out path — but the 72-run sweep of the shipped plugin failed to reproduce that deficit (v2 134s vs v1's 130s, within this task's run-to-run spread). Treat high-width tuning as a variance question needing more repetitions, not a measured gap.
- The width branch runs on the model's own width tally, not on anyone's label. At the margin they can disagree: in the sweep, two tasks the suite labeled width 6 were counted narrower by the model and ran solo — both still matched or beat baseline.

- v0.2.6 adds the MODE RE-DECISION clause: the width tally re-runs mid-turn when a build is born from a conversational opening (question/complaint → the model decides to build) or when a work-list materializes that the opening tally could not see; it counts implementation units, not symptom counts. This clause comes from a field observation (interactive sessions sliding from question to solo build), not from a measured win: a 4-design pre-registered ablation (`experiments/rewidth-eval.md`, research clone) could not reproduce the failure mode — current routing already re-tallied in every synthetic transcript, and in the conversational-entry design the solo it chose was the correct width. Shipped on operator judgment; if a captured real-session transcript later shows the failure, the clause gets a targeted benchmark, and if that benchmark shows no effect it comes back out, per stack policy.

---

v0.2.6 — by Jung Jiwon & Lee Jongkwan.
