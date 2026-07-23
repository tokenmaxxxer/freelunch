---
proposal: docs/proposals/2026-07-23-install-user-scope-only.md
---

# Hunt record — install-user-scope-only

## after-proposal — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — the kept user-scope `claude plugin marketplace add` call (no `--scope` flag, install.sh line ~316) mutates a repo's tracked project `.claude/settings.json` when run with cwd inside a repo that already declares the marketplace, even though the CLI reports the marketplace was "declared in user settings".
Kind: silent-failure
Seed: install.sh as it stands now (`--user` branch, lines 295-350); the proposal keeps this branch's marketplace add/update calls verbatim, unconditionally, with no `--scope` flag and no `cd` away from the invoking directory (unlike `write_bootstrap_hook`'s explicit "run from a scratch directory, never the repo" workaround, which only exists in the deleted project branch).

### Reproduce
Environment: real `claude` CLI 2.1.218 present, cwd = a git repo whose tracked `.claude/settings.json` already declares `extraKnownMarketplaces.tokenmaxxxer` + `enabledPlugins["tokenmaxxxer-env@tokenmaxxxer"]` (this repo's own dogfood file, prior to its proposed deletion — or, more generally, any repo that previously adopted the stack at project scope and committed the file).

```
cd /home/user/claude-plugins
git checkout -- .claude/settings.json   # known clean, committed baseline
md5sum .claude/settings.json            # 8ca75e70dfcc02491f411f00da8fca06
claude plugin marketplace remove tokenmaxxxer   # simulate a fresh account: marketplace not yet in ~/.claude
claude plugin marketplace add tokenmaxxxer/claude-plugins   # exactly install.sh's kept, no-`--scope` call
git diff .claude/settings.json
```
Reproduced 3 times in a row with identical result.

### Observed
CLI prints `√ Successfully added marketplace: tokenmaxxxer (declared in user settings) (+ 1 dependency: freelunch)` — claiming a user-scope-only effect — but the repo's tracked, committed `.claude/settings.json` is rewritten:

```diff
   "enabledPlugins": {
     "tokenmaxxxer-env@tokenmaxxxer": true,
+    "freelunch@tokenmaxxxer": true
   },
```
(plus key reordering of the whole file). `git status --short .claude/settings.json` shows the file as modified (`M`) purely as a side effect of a command the proposal's kept user-scope path issues with no `--scope` flag and no isolation from the invoking cwd.

### Expected
Per the proposal's boundary, `install.sh` (reduced to only the user-scope path) should never modify a project's tracked `.claude/settings.json`; `git status --short .claude/settings.json` should show no change, and the file's `enabledPlugins` should be untouched by a "user scope" install run from inside any repo that happens to have this file committed.
