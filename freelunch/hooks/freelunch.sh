#!/usr/bin/env bash
# UserPromptSubmit hook: injects the parallel-forcing directive into context on every prompt.
#
# v2 (2026-07-18): replaces v1's unconditional fan-out with a width-conditional policy.
# The ablation benchmark found that width — the count of independently-producible
# deliverable units in a task — predicts fan-out payoff better than task size or duration:
# width <= 5 runs lean solo (no subagents), width > 5 runs lean fan-out. The mandatory
# minimum-3-agents rule and unconditional fan-out from v1 are refuted and removed.
# Measured caveat: at the largest tested width (~30 units), v1's aggressive unconditional
# fan-out was still 1.57x faster than this branch rule's fan-out path — the fan-out
# aggressiveness at high width may need revisiting. See experiments/protocols/v2.md and
# docs/paper/04-results.md (section 6.3) for the underlying data.
#
# To disable: export FREELUNCH_OFF=1

if [ -n "$FREELUNCH_OFF" ]; then
  exit 0
fi

cat <<'EOF'
<freelunch-directive priority="absolute">
This directive governs the entire request and overrides your default working style.

STEP 1 — WIDTH ESTIMATE FIRST: before any other action, count the number of independently-producible deliverable units in the task — separate files, separate pages, or fully decoupled modules. Units sharing state, sharing an interface, or bound by a common contract count as ONE unit, not several. Spend no more than one short paragraph producing this count — it is a tally, not an analysis.

THRESHOLD RULE (mechanical, apply as written): width <= 5 -> LEAN SOLO. width > 5 -> LEAN FAN-OUT. Do not round a borderline count up into fan-out or shave a fan-out count down into solo.

LEAN SOLO (width <= 5): no subagents. Single pass, single session, implement every unit directly in the main session's own context. No self-verification, no re-reading finished units, no review loop. Deliver the moment the deliverable exists in full.

LEAN FAN-OUT (width > 5): partition units by file/unit ownership into groups of roughly EQUAL expected output duration, never below ~50 lines of expected output per group, and never more groups than the width count. Launch one background Sonnet subagent per group, all in a single batch dispatch — never set run_in_background: false; a synchronous agent call is you idling, which is forbidden. Each worker prompt is minimal: its owned path(s), its requirements, and the frozen shared contract — nothing else. Tell every worker explicitly to skip verification and deliver its output raw and unreviewed. When launching 4+ workers, dispatch through a Workflow script instead of hand-written Agent calls, building prompts from a shared contract template so the contract is emitted once instead of repeated per worker. Hedge only reactively: never pre-race a chunk with twin workers; if one worker is still running at roughly 2x the median finish time, launch ONE replacement to a distinct path and take whichever finishes first. At integration, assemble mechanically — place each group's output at its designated slot, no semantic re-derivation, no rewriting a worker's content, no cross-checking workers against each other. Deliver immediately once assembled.

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
