---
status: landed
files:
  - freelunch/.claude-plugin/plugin.json
  - tokenmaxxxer-env/.claude-plugin/plugin.json
  - dispatch/README.md
---

## Request (intent)

User: after landing this session's directive changes (soften-verbatim-capture already landed; branch-cleanup-rule pending approval), bump the plugin/marketplace version and deploy the update so users receive it.

## Constraints

- Bump only the version field(s) in the manifest file(s) discovered — state the current value(s) and the proposed next value(s) (choose semver bump appropriate to the change: doc/directive wording change → patch or minor; state which and why).
  - Discovered: `freelunch/.claude-plugin/plugin.json` has a `"version": "0.2.18"` field. This is the only version field found anywhere in the repo — no other plugin manifest (`doctrine`, `warrant`, `dispatch`, `scout`, `blueprint`, `no-mock`, `no-footgun`, `terse`, `tokenmaxxxer-env`) carries one, and `.claude-plugin/marketplace.json` (the marketplace manifest) has no top-level or per-plugin `version` field at all — it only lists `name`/`source`/`description` per plugin.
  - Current value: `0.2.18`. Proposed next value: `0.2.19` — a **patch** bump, because the pending changes (soften-verbatim-capture, branch-cleanup-rule) are directive/wording adjustments to existing behavior, not new capability or a breaking interface change.
  - Also in scope per user request: `tokenmaxxxer-env/.claude-plugin/plugin.json` DOES carry a `"version"` field — current value `"0.6.0"` — contrary to the earlier discovery note above (which was scoped to the freelunch-directive-change survey and did not check tokenmaxxxer-env). Proposed next value: `0.6.1` — a **patch** bump, since tokenmaxxxer-env is a dependency-only aggregator plugin with no code of its own; bumping it here just keeps its declared version moving in step with this release and is not tied to any semantic change in its own manifest content (dependency list unchanged).
- Deploy is outward-facing and hard-to-reverse: describe the exact deploy mechanism discovered (tag+push / merge / marketplace index) and require explicit user go before executing it — do NOT deploy as part of approval.
  - Discovered mechanism: there is **no git tag / GitHub Release convention** in this repo (`git tag` returns empty, no CHANGELOG file). The marketplace manifest (`.claude-plugin/marketplace.json`) points each plugin's `source` at a relative path (e.g. `./freelunch`) inside this same repo, keyed to the `tokenmaxxxer/claude-plugins` GitHub repo (per `install.sh` and README, which reference `raw.githubusercontent.com/tokenmaxxxer/claude-plugins/main/install.sh` and `/plugin marketplace add tokenmaxxxer/claude-plugins`). "Deploy" here concretely means: **merging the version bump to `main`** on GitHub — that is what user-side `/plugin marketplace` auto-update (or a manual `/plugin update`) pulls from. There is no separate tag/release step; `main` is the deploy artifact.
- gh is NOT installed; if deploy needs a GitHub release/tag, note it must be a git tag push or web-UI action.
  - No tag/release is required by the discovered mechanism (see above), so this constraint does not block deploy. If a tag were ever desired for traceability, it would have to be `git tag vX.Y.Z && git push origin vX.Y.Z` from the CLI (or the GitHub web UI), since `gh` is unavailable — but this is not part of the mechanism currently in use and is out of scope unless the user asks for it separately.
- The `dispatch/README.md` edit is doc-sync only: it mirrors the rule wording already landed in `dispatch/hooks/directive.sh` (main HEAD `806feb1`), and introduces no new behavior. This is the same drift class fixed earlier in commit `18cdbfe` (README convergence claim) — the README's "What it does" list mirrors the directive's rule bullets 1:1 and must not silently fall behind when a rule bullet changes.

## What will be done

1. Version field edit:
   - `freelunch/.claude-plugin/plugin.json` → `"version": "0.2.18"` → `"version": "0.2.19"`
   - `tokenmaxxxer-env/.claude-plugin/plugin.json` → `"version": "0.6.0"` → `"version": "0.6.1"`
2. Deploy step (gated on explicit user approval — not executed by approving this proposal):
   - Commit the version bump on a branch, open/merge a PR (or push directly if the user says so) to `main` on `tokenmaxxxer/claude-plugins`.
   - Concretely: `git checkout -b <branch>`, edit the file, `git commit`, `git push -u origin <branch>`, then merge to `main` (PR or direct push per user instruction). No `gh` command is required since no release/tag is part of this mechanism.
   - After merge, users receive the update via existing `/plugin marketplace` auto-update (if enabled) or by running `/plugin update` / re-running `install.sh`.
3. README sync: update `dispatch/README.md`'s rule/"What it does" list so it reflects the branch-cleanup rule already landed in `dispatch/hooks/directive.sh`. Mirror the directive's wording exactly — do not invent new behavior. The rule to add/sync: after a merge lands, the merged source branch is deleted post-merge — local deletion always (`git branch -d`), remote deletion only if the remote branch exists (guarded check before `git push origin --delete <branch>`), never deleting the target branch (e.g. `main`), and never deleting a branch that did not merge.

## Out of scope

- The directive content changes themselves (their own proposals) — soften-verbatim-capture and branch-cleanup-rule.
- Any manifest field other than `version` (name, description, author, source, dependencies, etc.).

## How we'll know it worked

- `freelunch/.claude-plugin/plugin.json` shows `"version": "0.2.19"` on `main`.
- `tokenmaxxxer-env/.claude-plugin/plugin.json` shows `"version": "0.6.1"` on `main`.
- The change has been merged/pushed to `main` on `tokenmaxxxer/claude-plugins` (the deploy mechanism discovered), which is what propagates to users via marketplace auto-update or manual `/plugin update` / re-run of `install.sh`.
- `dispatch/README.md`'s rule/"What it does" list includes the branch-cleanup rule (post-merge deletion: local always, remote only if it exists, never the target branch, never an unmerged branch) and matches `dispatch/hooks/directive.sh` wording — no drift between the two.
