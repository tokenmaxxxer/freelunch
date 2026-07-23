---
status: approved
files:
  - tokenmaxxxer-env/.claude-plugin/plugin.json
  - .claude-plugin/marketplace.json
  - install.sh
  - README.md
  - freelunch/README.md
---

# Rename bundle plugin: tokenmaxxxer-env → coding-agent-env

Issue: #27

## Request
Rename the one-install bundle plugin from `tokenmaxxxer-env` to `coding-agent-env`. The name should describe what the bundle sets up — the coding agent's operating environment — rather than repeat the marketplace/brand name.

## Constraints that change what gets built
- Only the plugin's own identity changes: its `name` field and its directory (`tokenmaxxxer-env/` → `coding-agent-env/`). The bundle contains no code — only `.claude-plugin/plugin.json` (confirmed: dir holds nothing else).
- The marketplace name (`tokenmaxxxer`) and the `@tokenmaxxxer` install suffix are unchanged — those are the marketplace identity. The install command becomes `/plugin install coding-agent-env@tokenmaxxxer`.
- This is a breaking change to the install reference: `tokenmaxxxer-env@tokenmaxxxer` stops existing; users install/update under the new name. The bundle is install-time only (pure dependency aggregator), so nothing at runtime breaks.
- Because a plugin's cache is keyed by name, the new name gets a fresh cache dir — no stale-cache problem like the version-bump issue (#24).
- The bundle's `dependencies` list (the plugins it pulls in) is unaffected — only the bundle's own name changes.
- References measured via grep: plugin.json `name`; marketplace.json `name`+`source`; install.sh (`BUNDLE=` var, header comment, the `plugin update` line); README.md (install command, stack table row, hand-declare fallback JSON key, layout list); freelunch/README.md (one comment line).

## What will be done
- `git mv tokenmaxxxer-env coding-agent-env`.
- `coding-agent-env/.claude-plugin/plugin.json`: `"name": "tokenmaxxxer-env"` → `"coding-agent-env"`.
- `.claude-plugin/marketplace.json`: the entry `name` `tokenmaxxxer-env` → `coding-agent-env` and `source` `./tokenmaxxxer-env` → `./coding-agent-env`.
- install.sh: `BUNDLE="tokenmaxxxer-env"` → `coding-agent-env`; header comment and the `claude plugin update tokenmaxxxer-env@tokenmaxxxer` line updated to the new name.
- README.md: install command, the `tokenmaxxxer-env` stack-table row + its `tokenmaxxxer-env/` link, the `"tokenmaxxxer-env@tokenmaxxxer": true` fallback key, and the layout-list directory name — all → `coding-agent-env`.
- freelunch/README.md: the "via the tokenmaxxxer-env bundle" comment → `coding-agent-env`.

## Out of scope
- The marketplace name `tokenmaxxxer` and any `@tokenmaxxxer` suffix.
- The repo name (`claude-plugins`) — that is a separate proposal (docs/proposals/2026-07-23-rename-coding-agent-rulebook.md), still unadopted.
- The bundle's version number and its dependency list.

## How I will know it worked
- `grep -rI "tokenmaxxxer-env" --exclude-dir=.git .` returns nothing outside `docs/` history.
- `coding-agent-env/.claude-plugin/plugin.json` exists with `"name": "coding-agent-env"`; the old dir is gone.
- marketplace.json's entry points `source` at `./coding-agent-env`; install.sh and both READMEs reference `coding-agent-env@tokenmaxxxer`.
