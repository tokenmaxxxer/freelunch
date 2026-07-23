---
proposal: docs/proposals/2026-07-23-rename-coding-agent-rulebook.md
---

# Hunt record — rename-coding-agent-rulebook

## after-proposal — stance 2: assume this guard goes silent when its own input is malformed — make it go silent

Verdict: FINDING — install.sh's "already registered" marketplace check keys only on the market *name*, never the repo path, so after the org's GitHub repo is renamed, a machine with the old repo already registered silently keeps pulling from the stale/renamed (soon-404) URL forever: `marketplace update`'s failure is swallowed by `>/dev/null 2>&1 || true`, `marketplace add` (which would have carried the new `GITHUB_REPO` path) is skipped entirely because the registration check passes, and the script still prints "installed the full stack" and exits 0.
Kind: silent-failure
Seed: docs/proposals/2026-07-23-rename-coding-agent-rulebook.md — repo path rename `tokenmaxxxer/claude-plugins` → `tokenmaxxxer/coding-agent-rulebook` propagated into `install.sh`'s `GITHUB_REPO`; install.sh lines ~112-118.

### Reproduce
```bash
cat > /tmp/mock-claude <<'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "plugin marketplace")
    case "$3" in
      list) echo "tokenmaxxxer  (github: tokenmaxxxer/claude-plugins)"; exit 0 ;;
      add) echo "SHOULD NOT BE CALLED"; exit 0 ;;
      update) echo "error: repository tokenmaxxxer/claude-plugins not found (404 - renamed)" >&2; exit 1 ;;
    esac
    ;;
  "plugin install"|"plugin update")
    echo "already up to date (using cached marketplace data)"; exit 0 ;;
esac
MOCK
chmod +x /tmp/mock-claude
PATH="$(dirname /tmp/mock-claude):$PATH" bash /home/jwjung/claude-plugins/install.sh; echo "EXIT=$?"
```

### Observed
```
    marketplace 'tokenmaxxxer' already registered
already up to date (using cached marketplace data)
[... x20]
==> installed tokenmaxxxer-env@tokenmaxxxer and the full stack.
==> done (user scope). ...
EXIT=0
```
The 404 from `marketplace update` (a stderr line saying the repo isn't found) is the only hint, and it is a debug-level line indistinguishable from noise, buried before 20 "already up to date" lines, followed by an unconditional success banner and exit 0.

### Expected
The registration check (or the `marketplace update` step) should detect that the registered source no longer resolves / no longer matches `GITHUB_REPO`, and either re-`add` with the corrected path or fail loudly (`install_failed`, non-zero exit) instead of reporting full success while running on a marketplace pointed at a repo that no longer exists at that path.
