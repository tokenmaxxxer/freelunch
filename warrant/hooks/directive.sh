#!/usr/bin/env bash
# UserPromptSubmit hook: injects the work-unit protocol.
#
# One gate, at the front. Everything after it runs without interruption — which
# is why the proposal has to carry the decisions that would otherwise become
# mid-build questions. freelunch forbids pausing MID-task; a pre-task gate is a
# different thing and the two compose unchanged.
#
# State lives on disk, not in the conversation: the proposal file's status field
# and the git branch survive session death, so state.sh can rebuild the picture
# at session start.
# Kill switch: export WARRANT_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${WARRANT_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<warrant-directive priority="high">
STANDING REQUEST FROM THE USER: work in this repository moves through one approval gate at the front. I am asking for the proposal before the code, every time — not as ceremony, as the thing I approve.

SURFACE GATE: applies when a turn would create, modify, or delete repository files as work. Conversation, questions, reading, and analysis are outside it — answer those directly. Once inside, this directive is the protocol until the work lands.

THE UNIT IS A PROPOSAL. One request, one proposal, one branch, one landing. It lives at `docs/proposals/YYYY-MM-DD-<slug>.md` with frontmatter:
```
---
status: proposed        # proposed -> approved -> landed
files:                  # the write set; nothing outside it gets edited
  - path/one.py
  - path/two.py
---
```
and a body of five short sections: the request's intent in one or two paraphrased sentences — first strip any credential, secret, token, personal data, or internal URL; then quote a short phrase only where exact NON-SENSITIVE wording changes what gets built (never quote the stripped material even if it is the load-bearing wording); the constraints stated so far that change what gets built; what will be done; what is deliberately out of scope; how you will know it worked. Keep it to what a reader needs — a typo fix is six lines, a subsystem is a page.

THE WRITE SET ANTICIPATES WHAT THE WORK WILL NEED. List every path the change will touch, not just the obvious one: the test file that covers it, `.env.example` when a new variable appears, the dependency manifest when something is added, the migration, the fixture. These are the parts I most want to see before approving — a new dependency or a new environment variable is a decision, and it belongs in the proposal rather than arriving unannounced during the build. Documents under `docs/` are the exception: those are the record the work produces, and they are always writable.

WRITE IT, THEN STOP. Create the proposal, say it is ready, and end the turn. Do not begin the work in the same turn. The proposal file itself is the only write this turn makes.

ON APPROVAL: set `status: approved`, create a branch, and build without stopping. The write set is frozen — every edit lands in a listed path. Choices that come up inside the scope are settled by the proposal's stated constraints and defaults and recorded in `decisions/`; they are never bounced back as questions.

WRITE DOWN WHAT DID NOT WORK, AT THE MOMENT IT DOES NOT WORK. The proposal grows one more section during the build — `## What did not work` — and lines get appended to it as the build goes, never saved up for landing. By landing, the failure has fallen out of your context and what you would write is a summary of the success. Appending is a write, not a pause, so it does not interrupt anything. Two conditions, both mechanical:
- you wrote something and then undid or replaced it -> one line: what it was, what broke it.
- something you expected to hold did not -> one line: what you expected, what actually happened instead.
That is the entire record. Not a transcript, not every attempt, and not a worker's internal dead ends — a worker that fails and retries inside its own task keeps that to itself. What belongs here is only what the NEXT person would otherwise try again, and it is the reason someone who was not in this conversation can pick the work up: the code shows what stands, this shows what already fell over.

SCOPE EXCEEDED: when the work turns out to need a file outside the write set, finish what the proposal covers, stop, and report what was found. Do not widen the set, do not ask mid-build. The remainder becomes the next proposal.

EVERY COMMIT CARRIES ITS WARRANT: the message ends with a trailer naming the proposal.
```
Proposal: docs/proposals/2026-07-22-<slug>.md
```
`git log --grep` then answers "what shipped for this proposal" without anyone maintaining an index.

ON LANDING: set `status: landed`. The durable parts of the proposal have homes of their own — system design goes to `docs/specs/`, the reason behind a hard-to-reverse choice to `docs/decisions/`, measurements to `docs/reports/`. `specs/` describes the system, so it changes only when the system's design changed; most proposals touch it not at all.

SEND A HUNTER AT THE TWO EXPENSIVE MOMENTS. Right after the proposal is written, and again right before the work lands, dispatch ONE background agent — `subagent_type: warrant-hunter`, `model: sonnet`, `run_in_background: true` — and carry on without waiting for it. The model is named explicitly because freelunch's enforcement mode denies any worker dispatch that does not carry it, and it cannot see the pin in this agent's own frontmatter. Give it one stance and the diff of that transition. The diff is the seed, not the fence: it names the pattern to hunt, and the hunter follows that pattern wherever in the repository it was copied to.

Take the stance at index `(dispatch count mod 5)`, counting from `.warrant-hunt.count` — never the one that seems apt. The apt-seeming stance is the one the code you just read suggested, so it probes only what that code already knows about itself, and rotating by hand collapses into a checklist:
0. assume the gate just touched is bypassable — find the bypass
1. assume this change and another plugin's rule cancel each other — find the pair
2. assume this guard goes silent when its own input is malformed — make it go silent
3. assume the rule as written cannot hold — find the state nothing maintains
4. assume the write set cannot carry this work — find the path the build will need that the proposal does not list
Tell it three things beyond the stance: the proposal's path, which transition this is (`after-proposal` or `before-landing`), and that its record goes to `docs/reports/<date>-hunt-<proposal-slug>.md`. Both dispatches append to that one file, and both leave a section even when they find nothing — a hunt nobody recorded reads exactly like a hunt nobody ran, and the `proposal:` field is what keeps the record attached to the unit that caused it, the same way the commit trailer does.

It returns one reproduced finding or nothing. A finding reaches the user at the next turn boundary, in one line; a hunter dispatched before landing reports into the landing exchange, because that is the last moment the finding is cheap. Never wait on it, never interrupt work for it, never dispatch a second while one is running — the guard refuses that anyway.

COMPOSITION: freelunch decides how the approved work is executed (solo or fan-out) — the write set is its ownership map. doctrine decides where documents land. This directive decides only what may begin and when.

NEVER:
- starting work in the turn that writes the proposal, or editing a path outside the frozen write set.
- pausing mid-build to ask a question the proposal should have settled.
- committing work without the `Proposal:` trailer.
- a second gate: after approval there is exactly one more exchange, the one where the work is reported.
</warrant-directive>
EOF
exit 0
