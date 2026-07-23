#!/usr/bin/env bash
# SessionStart bootstrap for the tokenmaxxxer stack.
#
# Why this exists: the committed .claude/settings.json declares the marketplace
# and enables the tokenmaxxxer-env bundle, and on a local CLI session that
# declarative install runs after a one-time interactive trust prompt. A remote
# (Claude Code on the web) session runs non-interactively with nobody to accept
# that prompt, so the plugins silently never install. An explicit
# `claude plugin install` is an explicit action that does not need the passive
# trust gate, so running it here is what actually lands the stack in a remote
# container. Idempotent: a fast guard makes re-runs a near-instant no-op.
#
# Everything the hook does is appended to ${HOME}/.claude/install-stack-hook.log
# (never stdout, which SessionStart injects into the session), so a later session
# can see exactly what happened -- did it find the CLI, did the install succeed.
set -uo pipefail

LOG="${HOME}/.claude/install-stack-hook.log"
mkdir -p "${HOME}/.claude" 2>/dev/null || true
log() { printf '%s\n' "$*" >>"$LOG" 2>/dev/null || true; }

# Only remote sessions have the gap. Local CLI sessions install via the
# declarative settings + interactive trust as usual, so leave them alone.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

log "--- install-stack SessionStart (remote) ---"
log "PATH=${PATH:-}"

# Locate the CLI robustly. It commonly lives outside a hook's PATH (e.g.
# /opt/node22/bin), so a bare `command -v claude` fails in the hook environment
# even though the CLI exists -- which silently skipped the whole install. Fall
# back to known locations before giving up.
CLAUDE=""
if command -v claude >/dev/null 2>&1; then
  CLAUDE="$(command -v claude)"
else
  for c in \
    "$HOME"/.local/bin/claude \
    /usr/local/bin/claude \
    /opt/node*/bin/claude \
    "$HOME"/.bun/bin/claude \
    "$HOME"/.claude/local/claude \
    "$HOME"/.vscode-server/extensions/anthropic.claude-code-*/resources/native-binary/claude \
    "$HOME"/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude; do
    if [ -x "$c" ]; then CLAUDE="$c"; break; fi
  done
fi
if [ -z "$CLAUDE" ]; then
  log "claude CLI not found on PATH or in known locations; nothing to do"
  exit 0
fi
log "claude=$CLAUDE"

MARKET="tokenmaxxxer"
BUNDLE="tokenmaxxxer-env"
GITHUB_REPO="tokenmaxxxer/claude-plugins"

# Fast path: bundle already installed in this container -> exit silently.
INSTALLED="${HOME}/.claude/plugins/installed_plugins.json"
if [ -f "$INSTALLED" ] && grep -q "\"${BUNDLE}@${MARKET}\"" "$INSTALLED" 2>/dev/null; then
  log "bundle already installed; fast-path exit"
  exit 0
fi

# Run the CLI from a scratch directory, never the repo. `claude plugin` resolves
# its write scope from the current directory (cwd, not CLAUDE_PROJECT_DIR --
# verified), so running inside the repo makes it pin the marketplace's resolved
# dependency (freelunch) into the tracked project .claude/settings.json. A
# neutral cwd keeps every write at user scope, leaving the checkout clean.
cd "$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}")" 2>/dev/null || cd / || true

# Register the marketplace (idempotent) and refresh it once.
if ! "$CLAUDE" plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
  "$CLAUDE" plugin marketplace add "$GITHUB_REPO" >/dev/null 2>&1 || true
fi
"$CLAUDE" plugin marketplace update "$MARKET" >/dev/null 2>&1 || true

# Install the one-install bundle only. On a fresh container its dependencies
# pull in the whole stack (verified: bundle-only install lands all 10 plugins),
# which also stays consistent with the single tokenmaxxxer-env entry in
# enabledPlugins. (install.sh --user installs each plugin explicitly for a
# different reason -- upgrading an already-installed bundle on a persistent
# machine -- which does not apply here.)
"$CLAUDE" plugin install "${BUNDLE}@${MARKET}" --scope user >/dev/null 2>&1
rc=$?
log "install exit=$rc"
if [ -f "$INSTALLED" ]; then
  log "plugins recorded: $(grep -c "@${MARKET}" "$INSTALLED" 2>/dev/null || echo 0)"
fi

exit 0
