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
