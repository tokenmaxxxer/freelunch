#!/usr/bin/env bash
# SessionStart bootstrap for the tokenmaxxxer stack.
#
# Why this exists: the committed .claude/settings.json declares the marketplace
# and enables the tokenmaxxxer-env bundle, and on a local CLI session that
# declarative install runs after a one-time interactive trust prompt. A remote
# (Claude Code on the web) session that runs non-interactively has nobody to
# accept that prompt, so the plugins silently never install. An explicit
# `claude plugin install` is an explicit action that does not need the passive
# trust gate, so running it here is what actually lands the stack in a remote
# container. Idempotent: a fast guard makes re-runs a near-instant no-op.
set -uo pipefail

# Only remote sessions have the gap. Local CLI sessions install via the
# declarative settings + interactive trust as usual, so leave them alone.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# No CLI on PATH -> nothing to do; never break the session over it.
command -v claude >/dev/null 2>&1 || exit 0

MARKET="tokenmaxxxer"
BUNDLE="tokenmaxxxer-env"
GITHUB_REPO="tokenmaxxxer/claude-plugins"

# Fast path: bundle already installed in this container -> exit silently.
INSTALLED="${HOME}/.claude/plugins/installed_plugins.json"
if [ -f "$INSTALLED" ] && grep -q "\"${BUNDLE}@${MARKET}\"" "$INSTALLED" 2>/dev/null; then
  exit 0
fi

# Register the marketplace (idempotent) and refresh it once.
if ! claude plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
  claude plugin marketplace add "$GITHUB_REPO" >/dev/null 2>&1 || true
fi
claude plugin marketplace update "$MARKET" >/dev/null 2>&1 || true

# Install the one-install bundle only. This is always a fresh container, so its
# dependencies pull in the whole stack (verified: a bundle-only install lands
# all 10 plugins). Installing the bundle alone is enough and stays consistent
# with the single tokenmaxxxer-env entry in enabledPlugins. (install.sh --user
# installs each plugin explicitly for a different reason — upgrading an
# already-installed bundle on a persistent machine — which does not apply here.)
claude plugin install "${BUNDLE}@${MARKET}" --scope user >/dev/null 2>&1 || true

# Keep stdout clean: SessionStart hook output is injected into the session.
exit 0
