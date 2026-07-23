---
status: landed
files:
  - install.sh
  - coding-agent-env/.claude-plugin/plugin.json
---

# install.sh: prune superseded bundle key from enabledPlugins

Issue: #30

## Request
Make install.sh's CLI-less fallback remove the pre-rename bundle key (`tokenmaxxxer-env@<market>`) from `enabledPlugins` when it writes settings, so a user who installed before the bundle rename and re-runs the installer is not left with both the dead key and the new `coding-agent-env@<market>` key.

## Constraints that change what gets built
- Repo scope only: install.sh runs on the user's machine and edits `~/.claude/settings.json`. The repo change is the installer's pruning logic; it takes effect the next time the user runs install.sh (per-user runtime state is otherwise out of the repo's reach — same boundary as #24).
- Only the CLI-less fallback path (`write_settings()`, [install.sh:43-88](install.sh#L43)) is in scope: it's the code that hand-writes `enabledPlugins`. The CLI path defers to `claude plugin install`, which owns its own state.
- The prune list is an explicit set of known-superseded keys — currently just `tokenmaxxxer-env`. Not a heuristic that guesses which plugins to disable (that could remove keys the user set deliberately).
- Existing behavior preserved: symlink write-through, `.bak` backup, list→dict normalization, and the new-key set all stay; the prune is one step inserted before the new key is set.

## What will be done
- In `write_settings()`'s embedded Python, after `enabled` is normalized to a dict and before `enabled[key] = True`, delete any key in a `SUPERSEDED = {f"tokenmaxxxer-env@{market}"}` set from `enabled` (with a printed note when one is removed, so the change is not silent).
- Bump the `coding-agent-env` bundle version 0.6.1 → 0.6.2 so the rename+fix release propagates to installed users (the cache-refresh lesson from #24).

## What is deliberately out of scope
- The CLI install path and `claude plugin`'s own enabledPlugins bookkeeping.
- The unconditional success banner wording (separate concern; the prune makes the resulting state correct).
- Reconciling already-broken settings.json on machines where the installer is never re-run — nothing in the repo can reach that.

## How I will know it worked
- Given a settings.json pre-seeded with `"tokenmaxxxer-env@tokenmaxxxer": true`, running the fallback write leaves `enabledPlugins` with `coding-agent-env@tokenmaxxxer: true` and no `tokenmaxxxer-env@tokenmaxxxer` key, and prints a line naming the removed key.
- A settings.json with no old key is unchanged except for the new key (no spurious removals).
