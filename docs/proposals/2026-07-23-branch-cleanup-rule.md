---
status: landed
files:
  - dispatch/hooks/directive.sh
---

## Request (intent)

None of the plugins specify deleting a branch after its work merges/lands, so merged branches accumulate on local and origin. User chose to rule-ify this (option 2): add a directive line so a merged/landed branch is cleaned up automatically going forward.

## Constraints

- Home is dispatch/hooks/directive.sh — it owns the issue→PR→merge lifecycle; the cleanup line attaches to the merge step.
- Rule: after a PR merges (or, when merged directly without a PR, after the branch lands on the target), delete the merged branch locally (`git branch -d`) always; delete it on remote (`git push origin --delete`) only if a remote copy actually exists (e.g. the branch has an upstream, or `git ls-remote --exit-code --heads origin <branch>` succeeds) — a local-only branch (never pushed, e.g. direct-landed without a PR) is skipped for the remote step without erroring. Never the target branch (main), and never a branch that did not merge.
- Edit only dispatch/hooks/directive.sh; a single short rule sentence added to the "MERGE ONLY ON EXPLICIT APPROVAL" area — no restructuring.

## What will be done

Add one rule sentence to dispatch/hooks/directive.sh mandating deletion of the merged source branch as the final step of a landing: local deletion is always required; remote deletion is conditional on the remote branch actually existing (checked via upstream or `git ls-remote --exit-code --heads origin <branch>`), so a local-only branch is cleaned up locally and the remote step is skipped without error. Scoped to never touch the target branch or an unmerged branch.

## Out of scope

- Retroactively deleting already-merged branches (e.g. the existing soften-verbatim-capture branch) — that is a separate one-off, not this rule.
- warrant landing lifecycle and any other plugin.
- The discarded scrub-approval-quote change.

## How we'll know it worked

dispatch/hooks/directive.sh's merge/landing section contains an explicit post-merge branch-deletion rule (local always, remote conditional on existence, target branch excluded); a memoryless reader lands a change and knows to delete the merged branch afterward, including the local-only (never-pushed) case: landing such a branch cleans it up locally and does not error on the missing remote ref.
