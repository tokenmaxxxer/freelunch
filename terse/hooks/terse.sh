#!/usr/bin/env bash
# UserPromptSubmit hook: injects the output-compression directive into context on every prompt.
#
# Design notes (v0.1.0, 2026-07-19): companion to freelunch, not a fork of Caveman.
# Caveman compresses everything the model says; terse compresses only the main
# session's conversational prose. Tool inputs — worker prompts, Workflow scripts,
# frozen contracts — are exempt because freelunch's fan-out correctness depends on
# their precision, and Caveman-style fragment compression there would corrupt the
# contract a worker receives. Safety-critical messages stay in full prose for the
# same reason Caveman exempts them: fragments are misreadable exactly where
# misreading is most expensive.
#
# State: one word in ~/.claude/terse.level (off | lite | full | ultra).
# Missing file means "full". The /terse command writes this file.
# Kill switch: export TERSE_OFF=1 (mirrors FREELUNCH_OFF).

if [ -n "$TERSE_OFF" ]; then
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

STATE_FILE="${HOME}/.claude/terse.level"
LEVEL="full"
if [ -f "$STATE_FILE" ]; then
  LEVEL="$(tr -d '[:space:]' < "$STATE_FILE")"
fi

case "$LEVEL" in
  off)
    exit 0
    ;;
  lite)
    STYLE="LEVEL lite: drop pleasantries, preamble, and restatements of the question. Keep full grammar and complete sentences. Cut sentences that add no information; do not shorten the ones that remain."
    ;;
  ultra)
    STYLE="LEVEL ultra: telegraphic. Sentence fragments, no articles or filler in English; in Korean drop everything except the minimum particles needed to keep subject/object unambiguous. One line per point. Prefer a bare table or list over prose whenever the content allows."
    ;;
  *)
    STYLE="LEVEL full: no pleasantries, no preamble, no restating the question, no offering follow-up work. Sentence fragments are fine where unambiguous. In Korean, keep particles that carry case or negation — dropping them can flip meaning; compress by deleting words, not by mangling grammar."
    ;;
esac

cat <<EOF
<terse-directive priority="high">
This directive governs the STYLE of your conversational output only. It never overrides task or orchestration directives (including any freelunch directive); where they conflict, orchestration wins.

${STYLE}

APPLIES TO: your prose replies to the user — status notes between tool calls, findings, summaries, explanations. Answer in the user's language, compressed by these rules.

NEVER COMPRESS (verbatim zones):
- Code, shell commands, file paths, config, and error messages — byte-for-byte.
- Tool inputs: subagent/worker prompts, Workflow scripts, and any frozen shared contract. These are load-bearing specifications, not conversation.
- Content written into repository files (docs, comments, commit messages) — repository conventions govern those.
- Safety-critical text: confirmations before destructive or hard-to-reverse actions, security warnings, and multi-step instructions the user must execute in order. Write these in full prose, then resume compression.

OUTPUT ECONOMY (applies at every level, on top of the level style):
- Never echo back code, diffs, or file content that already appeared in the conversation; reference the location (file:line) instead. Quote at most the single line under discussion.
- Formatting diet: headers, bold, and bullet scaffolding only when structure itself carries information; short answers are plain prose. No emoji, no decorative dividers.
- Do not narrate upcoming tool calls or re-describe completed steps the user already watched; one short status line only when direction changes.
- Do not re-summarize unchanged state; when updating, state only the delta since your last message.

SUBSTANCE RULE: compression removes filler, never information. If a detail changes what the reader does next, it stays. When compressed output would force the user to ask a follow-up question, you compressed the wrong thing.
</terse-directive>
EOF
exit 0
