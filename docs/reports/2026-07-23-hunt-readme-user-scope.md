---
proposal: docs/proposals/2026-07-23-readme-user-scope.md
---

# Hunt record — readme-user-scope

## after-proposal — stance 2: assume this guard goes silent when its own input is malformed — make it go silent.

Verdict: FINDING — install.sh's settings-only fallback swallows write_settings' JSON-validation failure and reports success (exit 0, "done") even though nothing was written.
Kind: silent-failure
Seed: install.sh (the CLI-less fallback path the rewritten README will document: `TOKENMAXXXER_SETTINGS_ONLY=1` / no `claude` CLI found -> write_settings "$HOME/.claude/settings.json")

### Reproduce
```
mkdir -p /tmp/fakehome/.claude
echo '{not valid json' > /tmp/fakehome/.claude/settings.json
HOME=/tmp/fakehome TOKENMAXXXER_SETTINGS_ONLY=1 bash /home/user/claude-plugins/install.sh
echo "SCRIPT_EXIT: $?"
cat /tmp/fakehome/.claude/settings.json   # unchanged: still malformed, nothing written
```

Instrumenting `write_settings`'s call site to print its own return code confirms the python
subprocess's `sys.exit(f"ERROR: ... is not valid JSON — fix it and re-run.")` guard fires and
returns 1, but `install.sh` never checks it (`write_settings "$HOME/.claude/settings.json"` is
called bare, no `||`, no `$?` check).

### Observed
```
==> no claude CLI found (standalone or bundled): writing user settings directly
ERROR: /tmp/fakehome/.claude/settings.json is not valid JSON — fix it and re-run.
    the bundle and its dependencies install on next session start
==> done (user scope). Start (or reload) a Claude Code session, then:
    - verify with /plugins
    ...
SCRIPT_EXIT: 0
```
settings.json is left untouched (still malformed), no marketplace/plugin entries were added, yet
the script prints the closing "done (user scope)" success banner and exits 0.

### Expected
When `write_settings` fails (its own JSON guard rejects malformed input), the outer script should
propagate that failure — non-zero exit, no "done" banner, and no "the bundle ... install on next
session start" claim — the same way the CLI-branch already tracks `install_failed` and reports it
explicitly instead of always printing the success line. As written, the one guard that exists for
this path (JSON validity check) is invisible to the operator: the ERROR line is the only signal,
sandwiched between routine output, immediately followed by unconditional success messaging and a
0 exit code that any calling script or CI step would read as "installed".

## before-landing — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — README claims the CLI-install path and the settings-only fallback "converge on exactly these two keys" with `enabledPlugins` holding only the bundle, but the CLI path's real, persisted `~/.claude/settings.json` ends up with 10 `enabledPlugins` entries (all 9 plugins plus the bundle), not the one-entry declaration shown.
Kind: design-error
Seed: README.md lines 42-89 (Install / Writing the settings by hand sections) vs install.sh's CLI loop (`for plugin in freelunch terse blueprint no-mock scout no-footgun doctrine warrant dispatch; do "$CLI" plugin install "$plugin@$MARKET" --scope user ...`) and its `write_settings()` fallback.

### Reproduce
```
# CLI path: run install.sh with a real `claude` CLI on PATH and a scratch HOME
export HOME=/tmp/testhome3   # scratch dir
cd /home/user/claude-plugins
bash install.sh
cat "$HOME/.claude/settings.json"

# Fallback path, same repo, forcing the settings-only branch
export HOME=/tmp/testhome2   # different scratch dir
cd /home/user/claude-plugins
TOKENMAXXXER_SETTINGS_ONLY=1 bash install.sh
cat "$HOME/.claude/settings.json"
```

### Observed
CLI path's `~/.claude/settings.json`:
```json
{
  "enabledPlugins": {
    "freelunch@tokenmaxxxer": true,
    "terse@tokenmaxxxer": true,
    "blueprint@tokenmaxxxer": true,
    "no-mock@tokenmaxxxer": true,
    "scout@tokenmaxxxer": true,
    "no-footgun@tokenmaxxxer": true,
    "doctrine@tokenmaxxxer": true,
    "warrant@tokenmaxxxer": true,
    "dispatch@tokenmaxxxer": true,
    "tokenmaxxxer-env@tokenmaxxxer": true
  },
  "extraKnownMarketplaces": { "tokenmaxxxer": { "source": { "source": "github", "repo": "tokenmaxxxer/claude-plugins" } } }
}
```
Fallback path's `~/.claude/settings.json` (matches README's shown JSON):
```json
{
  "extraKnownMarketplaces": { "tokenmaxxxer": { "source": { "source": "github", "repo": "tokenmaxxxer/claude-plugins" } } },
  "enabledPlugins": { "tokenmaxxxer-env@tokenmaxxxer": true }
}
```
The two on-disk declarations disagree on the very key the README singles out (`enabledPlugins`): 10 entries vs 1. This directly contradicts README.md line 44 ("Either path installs the same bundle the same way") and line 74 ("the declaration it converges on is exactly these two keys", followed by an example showing only the bundle enabled) — no code path makes the CLI's actual settings state match the single-entry declaration the README asserts both paths reach.

### Expected
Either README should not claim the two paths converge on the same settings declaration, or install.sh's CLI path should not persist per-plugin `enabledPlugins` entries beyond the bundle (matching what the fallback writes and what the README shows).
