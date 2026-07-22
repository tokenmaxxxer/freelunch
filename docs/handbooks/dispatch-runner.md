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

1. **Auth secret.** The action authenticates to Anthropic with a **pay-per-use
   Claude API key** — add `ANTHROPIC_API_KEY` (from console.anthropic.com) as a
   repository secret. Enterprise setups can use Amazon Bedrock / Google Vertex /
   Microsoft Foundry instead (`use_bedrock` / `use_vertex`). Per the official docs,
   the action's documented auth inputs are `anthropic_api_key` (+ `github_token`,
   `use_bedrock`, `use_vertex`) — a **Claude subscription (Pro/Max) is NOT a
   documented/supported auth method for the GitHub Action**. `claude setup-token`
   exists but is for local CLI automation, not this action. To run on a
   subscription instead of API billing, use Claude Code on the web
   (`subscribe_pr_activity` / auto-fix) rather than this workflow — at the cost of
   losing autonomous issue-triggered starts.
2. **The plugin is loaded by the workflow**, via the action's documented inputs
   (already wired in `dispatch.yml`) — no settings change is needed for the
   runner:
   ```yaml
   plugin_marketplaces: "https://github.com/tokenmaxxxer/claude-plugins.git"
   plugins: "dispatch@tokenmaxxxer"
   ```
   To also enable dispatch's composition partners, add them to `plugins`
   (e.g. `warrant@tokenmaxxxer`, `doctrine@tokenmaxxxer`). Separately, to enable
   the stack for humans who *open* the repo (not the runner), commit
   `extraKnownMarketplaces` + `enabledPlugins` to `.claude/settings.json` — a
   protected file, so add it by hand or with `/update-config`.

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
- Plugin loading uses the action's documented `plugin_marketplaces` + `plugins`
  inputs (v1). The self-contained `prompt` remains the fallback if a plugin fails
  to install, so the run still follows the git-only / ORIENT discipline.
- Authentication is a pay-per-use Claude API key (or Bedrock/Vertex/Foundry); a
  Claude subscription is not a documented auth method for the action (see Setup).
- This is a reference, not a hardened deployment: no rate limiting, no
  per-label routing, single prompt for all events.
