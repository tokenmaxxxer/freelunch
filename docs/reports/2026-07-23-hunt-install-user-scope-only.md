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

## before-landing — stance 1: assume this change and another plugin's rule cancel each other

Verdict: FINDING — README.md's "Install"/"Team rollout" sections still instruct a project-scope, repo-committed `.claude/settings.json` workflow that install.sh (post-change) can no longer produce under any invocation.
Kind: design-error
Seed: install.sh reduced to user-scope-only (no --project, no repo-root settings write); .claude/settings.json and .claude/hooks/install-stack.sh deleted from the repo.

### Reproduce
```
rm -rf /tmp/repro-repo && mkdir -p /tmp/repro-repo && cd /tmp/repro-repo && git init -q
TOKENMAXXXER_SETTINGS_ONLY=1 bash /home/user/claude-plugins/install.sh
ls -la .claude 2>&1   # per README's own next command: git add .claude/settings.json
```

### Observed
install.sh reports "done (user scope)" and writes only `$HOME/.claude/settings.json` (confirmed: `/root/.claude/settings.json` was created/updated). No `.claude/` directory is created in the repo at all — `ls .claude` in the freshly-initialized repo reports "No such file or directory". README.md's Install section (top of repo) still reads: "By default the installer writes `.claude/settings.json` at the repo root — **project scope**" and instructs the reader to run `git add .claude/settings.json && git commit -m "Add tokenmaxxxer plugin stack"` immediately after; that `git add` now has nothing to stage — the file the instruction depends on is never written. The "Team rollout" section below it repeats the same now-impossible claim ("commit the `.claude/settings.json` it writes and everyone who opens the repo ... gets the stack installed"), and the "Prefer to write the declaration by hand?" snippet is the same repo-root `extraKnownMarketplaces`/`enabledPlugins` block that install.sh no longer has any code path to produce. The commit that made this change (b66955b) says explicitly "README's --project references are a tracked follow-up," confirming the contradiction is real and currently unaddressed.

### Expected
Either install.sh keeps a way to write the repo-committed declaration (so README's rule holds), or README.md's Install/Team-rollout sections and the hand-written-declaration snippet are updated in the same change to describe only the user-scope flow — not left stating a repo-committed rule the code was just made incapable of satisfying.
