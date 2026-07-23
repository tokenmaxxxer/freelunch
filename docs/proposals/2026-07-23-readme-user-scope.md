---
status: landed          # proposed -> approved -> landed
issue: 20
files:
  - README.md
---

# Proposal: README — describe the user-scope-only installer

## The request (verbatim)

> ok. 그리고 README.md도 업데이트들이 필요해보여.

("ok. And README.md also looks like it needs updates.")

## Constraints that shape the build

1. `install.sh` now installs at user scope only (#19 removed `--project`, the
   committed `.claude/settings.json`, and the SessionStart bootstrap hook). The
   before-landing hunt (`docs/reports/2026-07-23-hunt-install-user-scope-only.md`)
   reproduced that README's Install / Team-rollout instructions are now false.
2. README.md also appears in the frozen write set of the still-open
   `2026-07-22-dispatch` proposal, but that unit is marked **Superseded (v0.5.0)**
   in its own body — its work shipped. Its README edits are done; this proposal
   takes README for the install-docs rewrite. If the scope gate contests it at
   build time, mark `2026-07-22-dispatch` landed (its status is stale) and
   proceed — no content of that unit is touched here.
3. Documentation-only change; install.sh itself is not touched (its behavior is
   already what README must now describe).

## What will be done

Rewrite the install-facing parts of README.md to match the current installer:
- Remove every `--project` / project-scope / `TOKENMAXXXER_SCOPE` reference and
  the "commit `.claude/settings.json` for a team rollout" narrative.
- State the single flow: run `install.sh` (or `install.sh --help`), which
  registers the marketplace and installs the stack at user scope via the CLI,
  with the settings-only fallback. No repo-committed declaration, no SessionStart
  hook.
- Keep the plugin catalogue / descriptions and everything unrelated to the
  install mechanism intact.

## Out of scope

- No change to install.sh or any plugin.
- No new install mechanism (setup-script / declarative guidance is a separate
  discussion, not this doc fix).

## How we will know it worked

- README has no `--project`, project-scope, or `git add .claude/settings.json`
  instruction, and no mention of a committed settings.json or SessionStart hook
  as the install path.
- Its install steps match what `install.sh` actually does today (user scope,
  marketplace + CLI install, settings fallback).

## What did not work

(Appended during the build, at the moment each thing does not work.)
