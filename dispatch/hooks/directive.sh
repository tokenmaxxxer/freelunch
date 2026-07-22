#!/usr/bin/env bash
# UserPromptSubmit hook: injects the git-as-sole-channel protocol.
#
# This is the judgment half of dispatch — which no path check can make: what
# counts as a settling point worth a discrete git object, when a report edits
# the live surface instead, and above all that a decision belongs on the remote,
# not in a chat turn that triggers no one and does not survive the session.
#
# The mechanical halves live next door: decision-lock.sh holds the oracle
# boundary (no second decision request, no landing or resolving your own), and
# report-gate.sh keeps commits attached to their unit. Neither reads generated
# content; both read the tool input.
#
# The state that matters lives on the REMOTE, not in this conversation: the
# committed `.dispatch/<unit>.decision.md` marker and the PR label survive
# session death, so a fresh run (or a stranger's clone) rebuilds who is waiting
# on whom. state.sh does that rebuild at session start.
# Kill switch: export DISPATCH_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${DISPATCH_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<dispatch-directive priority="high">
STANDING REQUEST FROM THE USER: in this repository the channel between me — the oracle, above — and you, the agent below, is git and nothing else. Every report you make is a git write; every git event is your trigger; so a report to me IS the next actor's trigger. Speak to me only through git.

SURFACE GATE: applies when a turn would (a) report progress or a result, (b) need a decision from me, or (c) hand work to or trigger another agent. Reading, analysis, and plain conversation that is not a report are outside it — answer those directly. Once inside, git is the only channel until the work terminates on the remote.

REPORT BY LIFETIME — one mutable surface plus discrete settling points, the same lifetime split doctrine applies to documents:
- LIVE STATUS (short-lived) -> edit ONE surface in place, never append: the PR body checklist, or `.dispatch/status.md` on the branch. Progress never becomes a new comment, and never a commit per thought.
- INCREMENT (medium) -> the commit message; the branch groups the commits.
- FINDING / QUESTION / OUTCOME (long-lived) -> a discrete git object at a SETTLING POINT only: a PR or issue comment, a decision record under `docs/`, a merge, a close with a reason. Promote to a discrete event only when something has settled; everything else edits the live surface. A comment per round is the firehose this rule exists to prevent — it destroys the signal density that makes the record worth reading.

NEED A DECISION FROM ME? DELIVER IT TO THE REMOTE AND STOP — never ask in chat, never idle in-process. A question typed into the reply, or an AskUserQuestion modal, cannot be subscribed to and does not outlive this session; a run that "waits" locally has delivered nothing, so no git event fires and neither I (a notification) nor a runner (a git event) is triggered — the block is invisible and you have in fact asked no one. Instead:
1. Write `.dispatch/<unit>.decision.md` with frontmatter `status: awaiting`, the question, and the options; COMMIT and PUSH it. This is the git-native truth a fresh session rebuilds the parked state from, with no API call.
2. Put the question on the unit's PR as a comment and add the `dispatch:awaiting-oracle` label — the subscribable surface I and the runner watch.
3. END THE RUN. You are not parked until the push and the comment have SUCCEEDED; before that you have asked no one and must not stop as if you had.
My answer arrives as a remote git event that triggers a FRESH run. That run reads the answer, removes the marker, and continues. You never answer, resolve, merge, or close your own decision request — that is my act, and git permissions, not you, enforce it.

TERMINATE ON THE REMOTE, always. Every triggered run ends by leaving its whole outcome as a remote git mutation and nothing in chat. Four shapes, all remote:
- PRODUCED   -> push commits / update the PR.
- PARKED     -> deliver the decision marker (above) and stop.
- IN PROGRESS-> edit the one live-status surface, push WIP.
- DEAD-END / OUT OF SCOPE -> push a diagnosis comment, close or label; the remainder becomes the next unit.
"Push the result" is only the PRODUCED case. The rule is the wider "terminate on the remote," which includes writing a not-done, waiting state. A local-only write, or a reply that carries the outcome only in chat, has triggered no one and, once the session ends, is gone.

REPORT == TRIGGER: author every report so its git write is also the next actor's trigger. A chat surface is allowed only as a VIEW over git-comment events — a typed message that lands as a comment — never as a side channel an agent cannot subscribe to. The moment an outcome exists only in chat, the identity breaks and the system falls back to un-triggerable chatbots.

COMPOSITION:
- warrant decides WHAT MAY BEGIN (its proposal and approval). dispatch decides how beginning, progress, and end are communicated and what re-triggers them. Under dispatch, approval and landing are my oracle git acts — a comment, a label, a merge, a close — not a chat "ok, go"; the `Proposal:` and `Dispatch:` trailers may name the same unit.
- doctrine decides WHERE A DOCUMENT LANDS. When a report is a document (a decision record, a report file), doctrine places it; dispatch never places a file, it governs the report as an EVENT and defers the file to doctrine.
- freelunch decides SOLO vs FAN-OUT. report==trigger is exactly what lets a fan-out hand off without an orchestrator — each worker's report is a git write that triggers the next actor.
- terse compresses report PROSE; dispatch chooses the report CHANNEL and GRANULARITY. Orthogonal.
- A warrant HUNTER's finding follows this directive: its record is a pushed report file; its finding is a PR comment, or a decision request with `dispatch:awaiting-oracle` when it must block the merge — never a chat one-liner, and never a value that lives only in the parent's context.

NEVER:
- asking in chat (an AskUserQuestion modal, or a question in the reply) when the decision belongs on the remote.
- idling in-process to "wait" for me; deliver the blocking state to the remote and terminate the run.
- treating a run as parked before the push and the comment have succeeded.
- answering, resolving, merging, or closing your own decision request.
- a comment per progress round; live status edits one surface in place.
- ending a run in chat with an outcome that never reached the remote.
</dispatch-directive>
EOF
exit 0
