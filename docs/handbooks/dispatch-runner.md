# dispatch runner (reference)

`.github/workflows/dispatch.yml` is a **reference git-event runner** for the
`dispatch` plugin. dispatch is the *discipline* half — how an agent behaves once
it is running (git is the only channel, orient before acting, deliver decisions
to the remote, terminate on the remote). This workflow is the *delivery* half —
it turns a GitHub event into a headless Claude Code run so the loop starts from
git without a human keeping a session open.

Together they close the model: **open an issue → a run is triggered → it scopes
the work and opens sub-issues and a PR → you comment on the PR to steer → it
re-aims → you merge to accept.**

## What triggers it

| Event (`on:`) | What the run does (ORIENT precedence) |
|---|---|
| `issues: [opened, assigned]` | scope a new unit; open the sub-issues and PR the work needs |
| `issue_comment: [created]` | a PR comment → next revision; an answer under a parked decision → resume that unit |
| `pull_request_review_comment: [created]` | a review-line comment → next revision |
| `pull_request: [opened, synchronize]` | a human push → continue / re-check the unit |

It runs in **automation mode** (the action has a `prompt` input), so it fires on
the event with no `@claude` mention. The `prompt` restates the core discipline,
so the run is well-behaved even if the plugin fails to load; the plugin adds the
full `ORIENT` directive and the oracle-boundary gates on top.

## Loop prevention

The job guard `if: github.event.sender.type != 'Bot'` is load-bearing: the
runner's own writes — its comments, pushes, sub-issues, and PRs — arrive with a
Bot sender, and waking another run on them is an infinite loop. Do not remove it.
`concurrency` keys on the issue/PR number with `cancel-in-progress: false`, so one
unit runs one at a time and a parked decision is never half-applied.

## Setup

1. **Auth secret.** Add one repository secret the action reads:
   - `ANTHROPIC_API_KEY`, or
   - `CLAUDE_CODE_OAUTH_TOKEN` via the `/install-github-app` flow (swap the
     `anthropic_api_key:` input for `claude_code_oauth_token:`).
2. **Enable the plugin in the runner** by adding this to `.claude/settings.json`
   (committed to the repo — the README's team-rollout; it also enables the stack
   for anyone who opens the repo). This file is protected, so add it by hand or
   with `/update-config`:
   ```json
   {
     "extraKnownMarketplaces": {
       "tokenmaxxxer": { "source": { "source": "github", "repo": "tokenmaxxxer/claude-plugins" } }
     },
     "enabledPlugins": { "tokenmaxxxer-env@tokenmaxxxer": true }
   }
   ```
   The `tokenmaxxxer-env` bundle now lists `dispatch` as a dependency, so this
   enables dispatch (with its composition partners) in every triggered run.

## Security notes

- **Untrusted event content.** Issue and comment bodies are attacker-controllable.
  The workflow passes only the event *name* and the issue/PR *number* into the
  prompt and has the agent read the content with tools, rather than interpolating
  raw bodies — keep it that way. Consider gating the job on
  `github.event.issue.author_association` (e.g. `OWNER`/`MEMBER`/`COLLABORATOR`)
  before acting on outside contributions.
- **Permissions** are `contents`, `issues`, `pull-requests: write`; the GitHub
  proxy restricts pushes to the current branch. Landing (merge) stays the
  oracle's act — the plugin's `decision-lock` refuses a merge while a unit is
  parked, and merges are left to a human by convention.

## Known caveats

- `pull_request_review` and label-triggered events are **not** in the `on:` list;
  add and test them if you need label-driven flows.
- Whether `claude-code-action` auto-installs the `enabledPlugins` from
  `.claude/settings.json` in the runner is version-dependent — verify against your
  action version. The self-contained `prompt` is the fallback if it does not.
- This is a reference, not a hardened deployment: no rate limiting, no
  per-label routing, single prompt for all events.
