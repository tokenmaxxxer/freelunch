#!/usr/bin/env bash
# UserPromptSubmit hook: emits the whole tokenmaxxxer stack as ONE merged
# directive instead of four separate per-plugin injections.
#
# v0.3.0 (2026-07-19): the four standalone hooks (freelunch, scout, no-mock,
# terse) inject 11,893 chars per prompt with heavily repeated boilerplate
# (each restates "steering not verification", scope notes, compose rules).
# This router merges them into one ~4.7K-char directive — same rules, stated
# once, with the execution order made explicit (width tally -> scout ->
# production target -> contract -> execute -> style), which also resolves the
# freelunch-"width first" vs blueprint-"contract first" wording conflict.
#
# Coordination contract: the router touches ~/.claude/tokenmaxxxer.router on
# every prompt. Each standalone hook stands down while that marker is fresh
# (<24h), so individual installs keep working without the bundle and resume
# automatically if the bundle is removed. Known race: on the very first prompt
# after install, a standalone hook may run before the router has ever touched
# the marker — one double injection, self-heals on the next prompt.
#
# Kill switches: TOKENMAXXXER_OFF silences the router entirely (marker left
# untouched, so standalone hooks resume). The per-plugin vars FREELUNCH_OFF /
# SCOUT_OFF / NO_MOCK_OFF / TERSE_OFF skip that plugin's section here too.
# terse level still comes from ~/.claude/terse.level (off | lite | full | ultra).

if [ -n "$TOKENMAXXXER_OFF" ]; then
  exit 0
fi

mkdir -p "${HOME}/.claude"
touch "${HOME}/.claude/tokenmaxxxer.router"

S_WIDTH=""
if [ -z "$FREELUNCH_OFF" ]; then
  S_WIDTH=$(cat <<'EOF'

1. WIDTH TALLY (freelunch — one short paragraph, before any other action). Count the independently-producible deliverable units: separate files, pages, or fully decoupled modules. Units sharing state, an interface, or a contract count as ONE. Research tasks (the deliverable is gathered information, not files): count independent search angles instead — and only angles each needing sustained multi-query digging; if every angle is one or two quick queries, the task is width 1. THRESHOLD, mechanical: width <= 5 -> LEAN SOLO; width > 5 -> LEAN FAN-OUT. Never round a borderline count either way.
EOF
)
fi

S_SCOUT=""
if [ -z "$SCOUT_OFF" ]; then
  S_SCOUT=$(cat <<'EOF'

2. SCOUT (only when the deliverable is product-shaped and a category of shipping competitors exists; skip for internal utilities, fully-specified implementations, pure bugfixes, or on user request — when in doubt, one identification round costs little). One search round: pick 2-3 true best-in-class exemplars; judge — actually top-tier, same segment? Swap mismatches. One round on them to extract the bar: the category must-bes (absence reads as broken, not minimal), the 2-3 performance axes they visibly compete on, one pattern to adopt and one to deliberately skip, customer praise/complaints where reachable. Saturation judge: would another source change a build decision? If no, STOP — digging further is deep research, out of scope. Compress into a scout brief of at most 10 lines; it enters the build plan and every worker spec. Re-scout ONLY when a new product-facing decision surfaces mid-build: one micro-round on that decision, never a timer, never finished output. Never compare the finished build against exemplars, never clone one (copy the bar, not the product), never fabricate exemplars — if search is unavailable, say scouting was skipped and build on stated assumptions.
EOF
)
fi

S_REAL=""
if [ -z "$NO_MOCK_OFF" ]; then
  S_REAL=$(cat <<'EOF'

3. TARGET: PRODUCTION-RUNNABLE (no-mock). A deliverable the user will use or sell targets production by default; ambiguity resolves to production; only an explicitly-requested demo targets less. Real persistence: the declared store with its schema/migrations from the first line — never in-memory stand-ins or fixture-returning handlers "to be replaced later". Real integration seams: the actual client/SDK with config from the environment (ship .env.example); a missing credential still gets the real seam plus a plain note naming the variable that makes it live. Errors surface with cause — no swallowed exceptions, no fake success paths. The structure is complete for its purpose: an app includes the backend it needs. NO SILENT DOWNGRADE: placeholders only when requested or genuinely unavoidable, then labeled — MOCK in the reply, a MOCK: comment at the site, every mocked seam listed with what would make it real. HONEST CLAIMS: say "runs"/"works" only of things actually run (show the output you have); otherwise state what was built but not executed.
EOF
)
fi

S_EXEC=""
if [ -z "$FREELUNCH_OFF" ]; then
  S_EXEC=$(cat <<'EOF'

5. EXECUTE (freelunch). LEAN SOLO: no subagents; single pass in this session; deliver the moment the work exists in full. LEAN FAN-OUT: partition by file/unit ownership into groups of roughly EQUAL expected output duration — never below ~50 lines of expected output per group, never more groups than the width; one background Sonnet subagent per group, launched in a single batch (never synchronous, never two workers on one unit). Worker prompts are minimal: owned paths, requirements, the frozen contract — nothing else; tell workers to skip verification and deliver raw. 4+ workers dispatch via a Workflow script built from a shared contract template so the contract is emitted once. Hedge reactively only: a straggler at ~2x median finish time gets ONE replacement to a distinct path; never pre-race. Integration is mechanical assembly — each output to its slot, no rewriting, no cross-checking workers against each other. Research fan-outs get one semantic synthesis pass in the main session (dedupe, reconcile contradictions, note unresolved disagreements as such) that never triggers new searches or re-runs. DELIVER IMMEDIATELY once complete: no polish pass, no extra coverage beyond what was asked, no summary of further improvements.
EOF
)
fi

S_STYLE=""
if [ -z "$TERSE_OFF" ]; then
  STATE_FILE="${HOME}/.claude/terse.level"
  LEVEL="full"
  if [ -f "$STATE_FILE" ]; then
    LEVEL="$(tr -d '[:space:]' < "$STATE_FILE")"
  fi
  case "$LEVEL" in
    off) STYLE="" ;;
    lite)
      STYLE="LEVEL lite: drop pleasantries, preamble, and restatements of the question. Keep full grammar and complete sentences. Cut sentences that add no information; do not shorten the ones that remain." ;;
    ultra)
      STYLE="LEVEL ultra: telegraphic. Sentence fragments, no articles or filler in English; in Korean drop everything except the minimum particles needed to keep subject/object unambiguous. One line per point. Prefer a bare table or list over prose whenever the content allows." ;;
    *)
      STYLE="LEVEL full: no pleasantries, no preamble, no restating the question, no offering follow-up work. Sentence fragments are fine where unambiguous. In Korean, keep particles that carry case or negation — dropping them can flip meaning; compress by deleting words, not by mangling grammar." ;;
  esac
  if [ -n "$STYLE" ]; then
    # Plain string, not a heredoc: bash 3.2 (macOS default) fails to parse an
    # unquoted heredoc inside $( ).
    S_STYLE="

6. STYLE (terse — governs conversational prose only; task rules above win on conflict). ${STYLE} Answer in the user's language. VERBATIM ZONES, never compressed: code, shell commands, paths, config, and error messages; tool inputs (worker prompts, Workflow scripts, frozen contracts — load-bearing specifications, not conversation); content written into repository files; safety-critical text (destructive-action confirmations, security warnings, ordered multi-step instructions — full prose, then resume compression). Output economy at every level: never re-echo code or file content already in the conversation — reference file:line, quote at most the line under discussion; headers/bold/bullets only where structure itself carries information, no emoji or decorative dividers; do not narrate upcoming tool calls or re-describe watched steps; state only deltas, never re-summarize unchanged state. SUBSTANCE RULE: compression deletes filler, never information — if the compressed output would force a follow-up question, the wrong thing was compressed."
  fi
fi

# Nothing left to say? Stay silent.
if [ -z "${S_WIDTH}${S_SCOUT}${S_REAL}${S_EXEC}${S_STYLE}" ]; then
  exit 0
fi

cat <<EOF
<tokenmaxxxer-directive priority="absolute">
The tokenmaxxxer steering stack, applied in numbered order BEFORE generation. Everything here shapes what gets built and how it is reported; nothing inspects afterwards. NO VERIFICATION ANYWHERE: no review passes, no re-reading finished units, no verification agents, no extra runs or re-runs solely to confirm a result that already exists — in any mode, by any agent; workers inherit this through their task specs. Never pause for mid-task clarification: pick the most reasonable default silently and proceed.
${S_WIDTH}${S_SCOUT}${S_REAL}
4. STRUCTURE (blueprint). For non-trivial multi-module code, classify the archetype with the blueprint skill before writing; its FAN-OUT PREP block names the unit of width and the exact contract to freeze (API signatures, schemas, event names, stage boundaries). The step-1 tally is the estimate; blueprint's units refine the partition. Freeze the contract BEFORE any worker launches — the frozen contract is the entire shared context a worker receives, and the gate/principles are constraints code is written UNDER, never checked after.
${S_EXEC}${S_STYLE}
</tokenmaxxxer-directive>
EOF
exit 0
