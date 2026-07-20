#!/usr/bin/env bash
# UserPromptSubmit hook: injects the parallel-forcing directive into context on every prompt.
#
# v2 (2026-07-18): replaces v1's unconditional fan-out with a width-conditional policy.
# The ablation benchmark found that width — the count of independently-producible
# deliverable units in a task — predicts fan-out payoff better than task size or duration:
# width <= 5 runs lean solo (no subagents), width > 5 runs lean fan-out. The mandatory
# minimum-3-agents rule and unconditional fan-out from v1 are refuted and removed.
# Measured caveat (softened 2026-07-19): in the validation data, v1's aggressive
# unconditional fan-out beat this branch rule's fan-out path at the largest tested
# width (~30 units), but the 72-run shipped-plugin sweep failed to reproduce that
# deficit (v2 133.7s vs v1's 129.8s, within run-to-run spread) — treat it as a
# variance question at high width, not a measured gap. Full-suite result for this
# policy: 1.50x geomean speedup, quality tied, cheaper tokens than baseline.
#
# v2.2 (2026-07-19): adds a research-task width rule. The deliverable-unit
# definition is code-shaped (files/modules), so research tasks always collapsed
# to width 1 — the final report is one artifact — even when the gathering stage
# has many independent search angles. Research width is now counted by
# independent search angles, gated by expected per-angle effort so tiny lookups
# stay solo, and research integration is exempted from the no-semantic-synthesis
# rule (reconciling contradictory sources IS the integration work). Untested
# against the benchmark suite as of this date.
#
# v2.3 (2026-07-20): fixes the solo-collapse bias observed in live sessions.
# Two rules compounded to route parallelizable work solo: (a) the width-merge
# clause counted ANY shared contract as ONE unit, collapsing exactly the tasks
# where fan-out pays most (multi-file deliverables sharing a freezable
# vocabulary/interface of a page or less); (b) the width>5 threshold counted
# units only, ignoring per-unit output volume. Width is now counted AFTER
# identifying a freezable contract — only non-freezable coupling (shared
# mutable state, sequential dependency, interface still being co-designed)
# merges units — and the threshold is width >= 3 AND ~100+ expected lines per
# unit. Routing A/B probe (12 ground-truth-labeled tasks x old/new directive,
# 24 router agents, decision-only): old misrouted 4/6 should-fan tasks to solo
# (including the real 5-document spec-suite case that motivated the fix, which
# old counted as width 1); new scored 12/12 with zero false fan-outs on the
# 6 should-solo tasks (single-file refactor, sequential migration, tiny
# configs, co-designed interface all still solo). End-to-end wall-clock and
# quality effect NOT yet measured against the benchmark suite. Probe data:
# experiments/routing-eval-v2.3.json (research repo).
#
# v2.4 (2026-07-20): allows symbol-level width (multiple workers producing one
# file, one per self-contained symbol, fixed-order concat assembly) — v2.3's
# merge rule read "same file = shared mutable state" and forbade it. A/B
# experiment (2 modules x 7 pure functions each; same frozen contract and
# pre-registered 60-test battery for both arms; Sonnet workers both arms):
# symbol arm 14 workers 64.2s, 57/60 tests; solo arm 2 agents 171.9s, 60/60 —
# 2.7x wall-clock gain, logic quality equal. The 3 failures were ONE seam
# defect (a worker omitted the `export` keyword), not logic — hence the new
# requirement that symbol-level contracts freeze each unit's exact
# export-signature line verbatim and workers start from it. Cost: 4.1x tokens
# (369k vs 90k) at ~65-line symbols; the existing ~100-line-per-unit threshold
# applies unchanged to symbol units and matters more, not less, at this
# granularity. Scope of evidence: self-contained pure functions (friendliest
# case); symbols sharing module-level helpers or co-mutating class state were
# NOT tested and remain merge-worthy coupling. Data:
# experiments/symbol-eval-v2.4.json (research repo).
#
# v2.5 (2026-07-20): tunes fan-out packing and worker effort from a 7-arm
# sweep on the symbol-eval corpus (2 modules x 7 functions, same frozen
# contract + pre-registered 60-test battery throughout; Sonnet workers).
# Packing curve (workers / wall-clock / tokens / tests):
#   k=1 x3 runs: 14w / 64-88s / ~370k / 60,60,57(pre-sig-freeze seam defect)
#   k=2:          8w / 74.5s  / 212k  / 60
#   k=4:          4w / 124.7s / 127k  / 60
#   solo:         2w / 171.9s / 90k   / 60
#   k=1 + low-effort workers: 14w / 12.8s / 356k / 60
# Findings encoded: (a) group floor "~50 lines" replaced by a ~100-200-line
# packing target — 2-symbol groups matched 1-symbol wall-clock within run
# variance while cutting tokens 43%; (b) low reasoning effort for workers on
# mechanical contract-pinned groups — 5x faster, quality intact (single run);
# (c) signature-freeze protocol re-validated: 5 sig-frozen arms, 76 workers,
# zero seam defects vs 1/14 without it. Single-corpus, single-run-per-arm
# caveats apply; wall-clock includes cross-workflow contention noise.
# Data: experiments/packing-eval-v2.5.json (research repo).
#
# To disable: export FREELUNCH_OFF=1

if [ -n "$FREELUNCH_OFF" ]; then
  exit 0
fi

cat <<'EOF'
<freelunch-directive priority="absolute">
This directive governs the entire request and overrides your default working style.

STEP 1 — CONTRACT SPLIT, THEN WIDTH: before any other action, WRITE one short paragraph in your visible reply (the paragraph is this step's deliverable; no style rule may compress it away): (a) name the shared contract you could freeze upfront (schema, interface, naming convention — a page or less); (b) count independently-producible units assuming that contract frozen. Units merge only under non-freezable coupling: same-line mutable state (distinct self-contained symbols in one file count as SEPARATE units when their export-signature lines are frozen), sequential dependency, or an interface still being co-designed. A freezable shared contract is never a merge reason. Note rough expected lines per unit.

RESEARCH TASKS: width = independent search angles needing sustained digging, not the report. One-or-two-query angles count zero (SCALE GATE).

THRESHOLD RULE (mechanical): width >= 3 AND ~100+ expected lines (or comparable effort) per unit → LEAN FAN-OUT; otherwise LEAN SOLO. Never round a borderline count either way; unknowable volume → estimate from comparable past outputs, not hope.

LEAN SOLO: no subagents, single pass, implement everything directly, deliver the moment it exists in full. No self-verification, no re-reading, no review loop.

LEAN FAN-OUT: freeze the contract verbatim first — it travels in every worker prompt. Partition by file/symbol ownership into groups of ~100-200 expected lines (measured optimum), roughly equal expected duration, never more groups than width. Symbol-level workers must start from their frozen export-signature line (measured: prevents the one observed seam-defect class). Contract-pinned mechanical groups dispatch at LOW reasoning effort (measured safe); judgment-needing groups at default. Launch one background Sonnet subagent per group in a single batch — never run_in_background: false. Worker prompt = owned paths + requirements + frozen contract, nothing else; tell workers to skip verification and deliver raw. 4+ workers → dispatch via a Workflow script built from a shared contract template. Hedge reactively only: one replacement if a worker runs ~2x median; never pre-raced twins. Integration is mechanical placement — no rewriting, no cross-checking. RESEARCH EXCEPTION: search-angle fan-outs integrate through one semantic synthesis pass (dedupe, reconcile, note disagreements as such), never new searches or re-runs.

MODE RE-DECISION: the tally binds to the deliverable, not the prompt's surface. Re-run STEP 1 on the remaining work when (1) DELIVERABLE BIRTH — a question/discussion/complaint turn is about to become a build: tally before the first Write/Edit, exactly as if the build had been requested directly; or (2) WORK-LIST MATERIALIZATION — a scan, file read, plan expansion, or just-finished unit reveals units the opening tally could not see: stop and re-tally before implementing them. Tally IMPLEMENTATION units, not symptom counts (six pages all fixed by one shared route = width 1-2, stay solo). Completed work never re-counts; each event fires once per discovery; never on a timer.

NEVER: two workers on one unit; any verification agent, review pass, re-read, or extra test run solely to confirm correctness; pausing for mid-task clarification (pick the reasonable default silently); re-running what already exists; fanning out regardless of width or enforcing minimum agent counts (both refuted).

DELIVER IMMEDIATELY once the mode's output is complete. No polish pass, no extra coverage beyond what was asked, no improvement summaries.
</freelunch-directive>
EOF
exit 0
