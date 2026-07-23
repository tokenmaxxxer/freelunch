---
proposal: docs/proposals/2026-07-23-rename-bundle-coding-agent-env.md
---

# Hunt record — rename-bundle-coding-agent-env

## after-proposal — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — the rename touches only repo files; it never reconciles the already-installed per-user plugin state (`~/.claude/settings.json` enabledPlugins and `~/.claude/plugins/installed_plugins.json`), which stays keyed on `tokenmaxxxer-env@tokenmaxxxer` forever after the rename, and the proposal's own verification step (repo-only grep) can never catch this.
Kind: silent-failure
Seed: docs/proposals/2026-07-23-rename-bundle-coding-agent-env.md — rename tokenmaxxxer-env → coding-agent-env across plugin.json, marketplace.json, install.sh, README.md, freelunch/README.md

### Reproduce
```
grep -n "tokenmaxxxer-env" /home/jwjung/.claude/settings.json /home/jwjung/.claude/plugins/installed_plugins.json
```

### Observed
```
/home/jwjung/.claude/plugins/installed_plugins.json:4:    "tokenmaxxxer-env@tokenmaxxxer": [
/home/jwjung/.claude/plugins/installed_plugins.json:7:        "installPath": "/home/jwjung/.claude/plugins/cache/tokenmaxxxer/tokenmaxxxer-env/0.6.1",
/home/jwjung/.claude/settings.json:4:    "tokenmaxxxer-env@tokenmaxxxer": true,
```
This is real, currently-live user-scope state on the machine that ran this hunt (installed via the marketplace at commit 1fa8bc7, per `gitCommitSha` in installed_plugins.json). The proposal's rename lands entirely inside the repo (plugin.json name, marketplace.json name+source, install.sh, two READMEs); nothing in its write-set or its "How I will know it worked" grep (`grep -rI "tokenmaxxxer-env" ... .` scoped to the repo) touches or even inspects this file. The proposal itself acknowledges the break ("`tokenmaxxxer-env@tokenmaxxxer` stops existing; users install/update under the new name") but treats it as merely a documented breaking change with no reconciliation step or migration note for the state that already exists per-installation — after the rename lands, `claude plugin update tokenmaxxxer-env@tokenmaxxxer` (still what a user with this settings.json runs, since nothing rewrites it) resolves against a marketplace entry that no longer exists, and `enabledPlugins["tokenmaxxxer-env@tokenmaxxxer"]` silently stops corresponding to anything the marketplace can serve — with no error surfaced at rename time.

### Expected
The proposal's success criteria should include (or its scope should explicitly exclude and flag) verification that no live `~/.claude/settings.json` / `installed_plugins.json` on any machine that adopted the bundle references the pre-rename name — or at minimum the proposal should name this as an out-of-repo state the rename cannot reconcile, rather than silently leaving it unaddressed while claiming "nothing at runtime breaks."
