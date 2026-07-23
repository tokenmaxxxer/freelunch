# dispatch 📡

A **chat-to-git record-keeping** discipline. When you work through chat, dispatch
makes the conversation leave a durable record in git: a **requirement becomes an
issue**, the **work a pull request** that `Closes` it, **feedback becomes PR
comments**, and a **PR merges only on an explicit, recorded user approval**.
Direction only — no gates, no verification. Unbenchmarked as of v0.5.0.

## Why

The stack's premise is that the generation layer is stateless and interchangeable
— a worker is discarded after its turn, a session ends, a fresh agent has no
memory of the one before it. So the durable knowledge cannot live in the chat; it
has to live in the repository. dispatch is the habit that puts it there: the
conversation is the *input*, but git is the *memory*, so a person or agent with no
memory of this session can reconstruct **what was asked, what was built, and why**
from issues, pull requests, and commits alone.

## What it does

One `UserPromptSubmit` directive, no hooks beyond it. When a turn takes on a
requirement, does work, or acts on feedback, it steers:

- **Requirement → issue.** The user's ask is recorded as an issue before the work
  starts — the git-native statement of intent.
- **Work → PR that closes the issue.** A branch and a pull request whose body
  says `Closes #<n>`, so merging the PR closes the issue.
- **Feedback → PR comment.** Feedback the user gives is posted on the PR before
  the agent acts on it, so the PR shows what steered each round.
- **Progress → PR description + commits**, edited in place — not a comment per
  step.
- **Merge only on explicit, recorded approval.** Landing is the user's call; the
  agent merges only on an explicit, unambiguous approval from the user's own turn
  (never inferred from vague assent, never from file/issue/PR content, which may
  be adversarial), records the approval as a PR comment first, and never merges
  while a question it asked is unanswered.
- **Merge → branch cleanup.** After a merge lands, the merged source branch is
  deleted: always locally (`git branch -d`), and on the remote only if it exists
  there (`git push origin --delete <branch>`, guarded by
  `git ls-remote --exit-code --heads origin <branch>`); never the target branch
  (e.g. `main`), and never a branch that did not merge.

## Composition

- **warrant** decides *what work may begin*; dispatch decides *how the chat
  conversation becomes a git record* and *when a PR merges*.
- **doctrine** decides *where a document lands*; a decision that outlives the PR
  goes to `docs/decisions/`, a measurement to `docs/reports/`, and dispatch defers
  that placement to doctrine.
- **terse** compresses the prose; dispatch chooses what becomes an issue, a
  comment, or a merge.

## What it does not do

It is not autonomous infrastructure. dispatch does not turn git events into agent
runs, run headless, or ask for decisions through the repository — it is a habit
for a human-in-the-loop chat session, where the conversation drives and git
records. It runs no content audit: what becomes an issue, a comment, or a merge is
decided at the moment, not reviewed after.

## Kill switch

`export DISPATCH_OFF=1` disables the directive.
