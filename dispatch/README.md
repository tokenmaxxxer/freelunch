# dispatch 📡

Make git the **sole channel** between an agent and the oracle above it. Every
report is a git write, every git event is a trigger — so a report *is* the next
actor's trigger. A needed decision is delivered to the remote as a blocking
marker and label, not asked in chat; the run then terminates rather than idling
in-process. Direction plus two mechanical gates; no verification, no content
review. Unbenchmarked as of v0.1.0.

## Why a channel plugin

The stack splits generation (the agent, below) from verification (the human
oracle, above). For that split to run as a *system* — agents triggering agents,
the human as one more actor — the two layers must talk over a substrate other
agents can subscribe to. Chat cannot be subscribed to and does not survive a
session; git can. dispatch makes the agent speak only through git, so:

- **`report == trigger`.** Outbound is a git write and inbound is a git event, so
  an agent's report is the next actor's trigger. This identity only holds if git
  is the *sole* channel — one ephemeral chat message for a hand-off breaks it.
- **The oracle stays above, as a git act.** Approval and landing are the human's
  `merge` / `close` / label — enforced by git permissions, not app logic. The
  agent never accepts, merges, or resolves its own work.
- **Waiting is a remote delivery, not a local hold.** A run that idles locally
  delivers nothing: no remote object, no event, no trigger — the block is
  invisible. "Parked on the oracle" is a property of *remote git state*, so the
  agent delivers the blocking state and terminates; a fresh run, triggered by the
  answer, resumes from the remote.

## What it does

- **Directive** (`UserPromptSubmit`) — the judgment half: report by lifetime (one
  mutable status surface plus discrete settling points), deliver a decision to
  the remote and stop, terminate on the remote in one of four shapes
  (produced / parked / in progress / dead-end), and `report == trigger`.
- **decision-lock** (`PreToolUse`) — the oracle boundary: refuses a second open
  decision request, refuses mutating an existing marker (you do not answer your
  own question), and refuses a merge while a unit is parked.
- **report-gate** (`PreToolUse`) — keeps work attached to its unit
  (`Dispatch: <branch>` commit trailer on a feature branch) and refuses poking
  `.dispatch/` state around the bus by shell.
- **state** (`SessionStart`) — fetches and reads the committed
  `.dispatch/*.decision.md` markers, reporting which units are parked on the
  oracle. Rebuilds from the remote-delivered state; writes nothing.

## The decision request

When the agent needs the oracle it delivers, then terminates:

```
.dispatch/<unit>.decision.md      # committed + pushed — the git-native truth
---
unit: <branch-or-id>
status: awaiting                  # awaiting -> resolved (resolution is the oracle's remote act)
pr: <url-or-number>
---
QUESTION: <one line>
OPTIONS:  A | B
BLOCKED:  no default — this waits on the oracle
```

plus a `dispatch:awaiting-oracle` label and a marker comment on the PR (the
subscribable surface). The run is not parked until the push and the comment have
succeeded. The oracle's answer is a remote git event that triggers a fresh run,
which reads it, removes the marker with `git rm`, and continues.

## Composition

- **warrant** owns *what may begin*; dispatch owns *how it is communicated and
  re-triggered*. Approval and landing become the oracle's git acts; the
  `Proposal:` and `Dispatch:` trailers may name the same unit.
- **doctrine** places any report that is a document; dispatch governs the report
  as an *event* and never places a file.
- **freelunch** decides solo vs fan-out; `report == trigger` is what lets a
  fan-out hand off without an orchestrator.
- **terse** compresses report prose; dispatch chooses the channel and
  granularity.

## What it does not do

It does not build the bus. dispatch steers an agent already running in a
git-event environment; the always-on runner that maps a git event to an agent run
is infrastructure (a webhook receiver, a session spawner), not a plugin — a
partial one already exists wherever an agent can subscribe to PR activity. And it
runs no content audit: placement and granularity happen at write time, consistent
with the stack's no-verification thesis.

## Kill switch

`export DISPATCH_OFF=1` disables every hook. All gates fail open on a missing
`python3`, an unreadable payload, or an unexpected schema.
