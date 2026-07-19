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
# See experiments/results.csv and docs/paper/04-results.md (section 5.5).
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

STEP 1 — CONTRACT SPLIT, THEN WIDTH: before any other action, spend one short paragraph doing two things in order. (a) Identify any shared contract in the task — a schema, interface, id/vocabulary convention, or style guide — that could be frozen upfront in compact form (roughly a page or less). (b) Count the independently-producible deliverable units ASSUMING that contract is frozen: separate files, pages, or modules that a worker could each produce holding only the frozen contract. Units merge into ONE unit only under NON-FREEZABLE coupling: shared mutable state (two units editing the SAME lines — distinct self-contained symbols within one file, assembled by fixed-order concatenation, count as separate units PROVIDED the contract freezes each unit's exact export-signature line verbatim), sequential dependency (unit B's content is determined by unit A's finished output), or an interface still being co-designed during the work itself. Sharing a freezable contract is NOT a merge reason — distributing a frozen contract to workers is exactly what fan-out mode does. While counting, note the expected output volume per unit (rough line count); the threshold uses it. This is a tally, not an analysis.

RESEARCH TASKS (the deliverable is gathered information — a report, survey, or answer — rather than code or files): do NOT count the final report as the unit. Count width as the number of independent search angles — distinct sources, modalities, or query families that share no state (e.g. official docs, community lists, forums, academic literature, news). SCALE GATE: if the expected gathering work per angle is one or two quick queries, the whole task is width 1 regardless of angle count — dispatch overhead exceeds the parallel gain. Only angles each needing sustained multi-query digging count toward width.

THRESHOLD RULE (mechanical, apply as written): LEAN FAN-OUT when width >= 3 AND expected output averages >= ~100 lines (or comparable sustained effort) per unit. Otherwise LEAN SOLO — width <= 2, or units too small to amortize dispatch overhead. Do not round a borderline count up into fan-out or shave a fan-out count down into solo; when volume is genuinely unknowable, estimate from comparable past outputs, not hope.

LEAN SOLO: no subagents. Single pass, single session, implement every unit directly in the main session's own context. No self-verification, no re-reading finished units, no review loop. Deliver the moment the deliverable exists in full.

LEAN FAN-OUT: freeze the shared contract first, verbatim — it travels in every worker prompt. Then partition units by file- or symbol-level ownership into groups (symbol-level groups — several workers producing one file — are assembled by fixed-order concatenation, and each such worker prompt MUST begin from its frozen export-signature line: the one observed symbol-level failure class is a worker drifting from the export seam, and the signature line prevents it at the contract, not by verification) of roughly EQUAL expected output duration, packed to ~100-200 expected lines per group (measured optimum: 2-symbol groups cost the same wall-clock as 1-symbol groups — within run variance — while spending ~43% fewer tokens; bigger groups keep saving tokens but pay real latency, ~+70% at 4-symbol groups), and never more groups than the width count. When a group's work is mechanical — the frozen contract already pins signatures and edge-case semantics, leaving no design judgment — dispatch its worker at LOW reasoning effort: measured 5x wall-clock reduction with zero quality loss on contract-pinned units; keep default effort when the unit requires judgment beyond the contract. Launch one background Sonnet subagent per group, all in a single batch dispatch — never set run_in_background: false; a synchronous agent call is you idling, which is forbidden. Each worker prompt is minimal: its owned path(s), its requirements, and the frozen shared contract — nothing else. Tell every worker explicitly to skip verification and deliver its output raw and unreviewed. When launching 4+ workers, dispatch through a Workflow script instead of hand-written Agent calls, building prompts from a shared contract template so the contract is emitted once instead of repeated per worker. Hedge only reactively: never pre-race a chunk with twin workers; if one worker is still running at roughly 2x the median finish time, launch ONE replacement to a distinct path and take whichever finishes first. At integration, assemble mechanically — place each group's output at its designated slot, no semantic re-derivation, no rewriting a worker's content, no cross-checking workers against each other. Deliver immediately once assembled. RESEARCH EXCEPTION: when the fan-out was over search angles, integration is a single semantic synthesis pass in the main session — dedupe findings, reconcile contradictions between sources, and note unresolved disagreements as such. This synthesis never triggers new searches or worker re-runs; it works only with what the workers returned.

NEVER:
- more than one worker assigned to the same unit of width.
- a verification agent, review pass, re-read, or extra test run performed solely to confirm correctness, under either mode.
- pausing for mid-task clarification questions; pick the most reasonable default silently and proceed.
- a re-run performed only to double-check a result that already exists.
- fanning out regardless of width, or enforcing a minimum agent count irrespective of width — both refuted; the threshold rule above is the only trigger.

DELIVER IMMEDIATELY once the applicable mode's output is complete. No polish pass, no extra coverage beyond what was asked, no summary of further improvements.
</freelunch-directive>
EOF
exit 0
