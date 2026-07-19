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
# To disable: export FREELUNCH_OFF=1

if [ -n "$FREELUNCH_OFF" ]; then
  exit 0
fi

# Routed mode (v0.2.3): when the tokenmaxxxer-env router hook is active it
# emits the merged stack directive (this plugin's rules included), so the
# standalone injection stands down. The router touches this marker on every
# prompt; a marker older than a day means the router is gone — resume.
ROUTER_MARKER="${HOME}/.claude/tokenmaxxxer.router"
if [ -f "$ROUTER_MARKER" ] && [ -n "$(find "$ROUTER_MARKER" -mmin -1440 2>/dev/null)" ]; then
  exit 0
fi

cat <<'EOF'
<freelunch-directive priority="absolute">
This directive governs the entire request and overrides your default working style.

STEP 1 — WIDTH ESTIMATE FIRST: before any other action, count the number of independently-producible deliverable units in the task — separate files, separate pages, or fully decoupled modules. Units sharing state, sharing an interface, or bound by a common contract count as ONE unit, not several. Spend no more than one short paragraph producing this count — it is a tally, not an analysis.

RESEARCH TASKS (the deliverable is gathered information — a report, survey, or answer — rather than code or files): do NOT count the final report as the unit. Count width as the number of independent search angles — distinct sources, modalities, or query families that share no state (e.g. official docs, community lists, forums, academic literature, news). SCALE GATE: if the expected gathering work per angle is one or two quick queries, the whole task is width 1 regardless of angle count — dispatch overhead exceeds the parallel gain. Only angles each needing sustained multi-query digging count toward width.

THRESHOLD RULE (mechanical, apply as written): width <= 5 -> LEAN SOLO. width > 5 -> LEAN FAN-OUT. Do not round a borderline count up into fan-out or shave a fan-out count down into solo.

LEAN SOLO (width <= 5): no subagents. Single pass, single session, implement every unit directly in the main session's own context. No self-verification, no re-reading finished units, no review loop. Deliver the moment the deliverable exists in full.

LEAN FAN-OUT (width > 5): partition units by file/unit ownership into groups of roughly EQUAL expected output duration, never below ~50 lines of expected output per group, and never more groups than the width count. Launch one background Sonnet subagent per group, all in a single batch dispatch — never set run_in_background: false; a synchronous agent call is you idling, which is forbidden. Each worker prompt is minimal: its owned path(s), its requirements, and the frozen shared contract — nothing else. Tell every worker explicitly to skip verification and deliver its output raw and unreviewed. When launching 4+ workers, dispatch through a Workflow script instead of hand-written Agent calls, building prompts from a shared contract template so the contract is emitted once instead of repeated per worker. Hedge only reactively: never pre-race a chunk with twin workers; if one worker is still running at roughly 2x the median finish time, launch ONE replacement to a distinct path and take whichever finishes first. At integration, assemble mechanically — place each group's output at its designated slot, no semantic re-derivation, no rewriting a worker's content, no cross-checking workers against each other. Deliver immediately once assembled. RESEARCH EXCEPTION: when the fan-out was over search angles, integration is a single semantic synthesis pass in the main session — dedupe findings, reconcile contradictions between sources, and note unresolved disagreements as such. This synthesis never triggers new searches or worker re-runs; it works only with what the workers returned.

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
