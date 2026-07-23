#!/usr/bin/env bash
# One-shot installer for the tokenmaxxxer stack.
# Registers the marketplace, installs the tokenmaxxxer-env bundle (which pulls
# every plugin in as a dependency), and refreshes the marketplace once.
#
# Two scopes:
#   project (default)   Writes .claude/settings.json at the root of the git repo
#                       you run this in. Commit that file and everyone who opens
#                       the repo — local CLI, Claude Code on the web, and Slack
#                       cloud sessions — gets the stack installed and enabled on
#                       session start. Because the file is shared, the
#                       marketplace source is always the GitHub repo (a local
#                       directory path would not resolve elsewhere). Refuses to
#                       run outside a git repository so a stray settings.json is
#                       never scattered into an unrelated directory.
#   user (--user)       Installs for your account only. Uses a real `claude` CLI
#                       (standalone, or the binary bundled inside the VSCode
#                       extension) at --scope user, or falls back to writing
#                       ~/.claude/settings.json directly. Applies on every
#                       machine-local session but does NOT travel with any repo.
#
# Select the scope with --project / --user, or TOKENMAXXXER_SCOPE=project|user.
# A flag overrides the environment variable.
set -u

MARKET="tokenmaxxxer"
BUNDLE="tokenmaxxxer-env"
GITHUB_REPO="tokenmaxxxer/claude-plugins"

usage() {
  cat <<'USAGE'
Usage: install.sh [--project | --user]

  --project   (default) Write .claude/settings.json at the current git repo root
              so the repo carries the stack. Commit it; local CLI and cloud/Slack
              sessions pick it up on session start. Must be run inside a git repo.
  --user      Install for your account only. Applies to every machine-local
              session but does not travel with any repo, and does not reach
              Claude Code on the web / Slack cloud sessions.
  -h, --help  Show this help.

Environment:
  TOKENMAXXXER_SCOPE=project|user   Same as the flags (a flag overrides it).
  TOKENMAXXXER_SETTINGS_ONLY=1      User scope: skip the CLI and write settings
                                    directly.
USAGE
}

SCOPE="${TOKENMAXXXER_SCOPE:-project}"
while [ $# -gt 0 ]; do
  case "$1" in
    --project) SCOPE="project" ;;
    --user)    SCOPE="user" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
case "$SCOPE" in
  user|project) ;;
  *) echo "install.sh: TOKENMAXXXER_SCOPE must be 'project' or 'user' (got '$SCOPE')" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
if [ "$SCOPE" = "project" ]; then
  # A committed settings.json is read on other machines and in cloud sessions,
  # so the source must be portable: always the GitHub repo, never a local path.
  MARKET_SOURCE="$GITHUB_REPO"
  SETTINGS_SOURCE_JSON="{\"source\": \"github\", \"repo\": \"$GITHUB_REPO\"}"
elif [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/.claude-plugin/marketplace.json" ]; then
  MARKET_SOURCE="$SCRIPT_DIR"
  SETTINGS_SOURCE_JSON="{\"source\": \"directory\", \"path\": \"$SCRIPT_DIR\"}"
else
  MARKET_SOURCE="$GITHUB_REPO"
  SETTINGS_SOURCE_JSON="{\"source\": \"github\", \"repo\": \"$GITHUB_REPO\"}"
fi

# Merge extraKnownMarketplaces + enabledPlugins into a settings.json at $1,
# preserving any existing content. Used for both the project file and the
# user-scope CLI-less fallback.
write_settings() {
  python3 - "$MARKET" "$BUNDLE" "$SETTINGS_SOURCE_JSON" "$1" <<'PY'
import json, os, shutil, sys

market, bundle, source_json, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
key = f"{bundle}@{market}"
path = os.path.expanduser(path)
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
# A dotfiles setup often symlinks this file. os.replace() below would swap the
# link for a regular file and quietly detach the user's real settings, so write
# through to whatever it points at.
if os.path.islink(path):
    path = os.path.realpath(path)
    print(f"    settings.json is a symlink; writing through to {path}")

settings = {}
if os.path.exists(path):
    with open(path) as f:
        try:
            settings = json.load(f)
        except ValueError:
            sys.exit(f"ERROR: {path} is not valid JSON — fix it and re-run.")
    shutil.copy2(path, path + ".bak")
    print(f"    backup written to {path}.bak")

settings.setdefault("extraKnownMarketplaces", {})[market] = {
    "source": json.loads(source_json)
}

# enabledPlugins is a record ({"plugin@market": true}), not an array.
enabled = settings.get("enabledPlugins")
if isinstance(enabled, list):
    enabled = {k: True for k in enabled}
elif not isinstance(enabled, dict):
    enabled = {}
enabled[key] = True
settings["enabledPlugins"] = enabled

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print(f"    updated {path}")
PY
}

# Write the SessionStart bootstrap hook next to a project settings.json and
# register it. The declarative enabledPlugins above installs the stack on a
# local CLI session (after a one-time interactive trust prompt), but a remote
# Claude Code on the web session runs non-interactively with nobody to accept
# that prompt, so the stack silently never installs there. This hook runs an
# explicit `claude plugin install` — which does not need the passive trust gate
# — in remote sessions, idempotently. $1 is the repo root.
write_bootstrap_hook() {
  local root="$1"
  mkdir -p "$root/.claude/hooks"
  cat > "$root/.claude/hooks/install-stack.sh" <<'HOOK'
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

# Run the CLI from a scratch directory, never the repo. `claude plugin` resolves
# its write scope from the current directory (cwd, not CLAUDE_PROJECT_DIR --
# verified), so running inside the repo makes it pin the marketplace's resolved
# dependency (freelunch) into the tracked project .claude/settings.json. That
# dirties the repo on every session and trips stop hooks. A neutral cwd keeps
# every write at user scope, leaving the checkout clean.
cd "$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}")" 2>/dev/null || cd / || true

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
HOOK
  chmod +x "$root/.claude/hooks/install-stack.sh"
  echo "    wrote $root/.claude/hooks/install-stack.sh"

  # Merge the SessionStart hook into the project settings.json (idempotent).
  python3 - "$root/.claude/settings.json" <<'PY'
import json, os, sys

path = sys.argv[1]
cmd = "$CLAUDE_PROJECT_DIR/.claude/hooks/install-stack.sh"
with open(path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
starts = hooks.setdefault("SessionStart", [])
# Already registered? Leave it alone.
present = any(
    h.get("command") == cmd
    for group in starts
    for h in group.get("hooks", [])
)
if not present:
    starts.append({"hooks": [{"type": "command", "command": cmd}]})
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)
    print(f"    registered SessionStart bootstrap hook in {path}")
else:
    print(f"    SessionStart bootstrap hook already registered in {path}")
PY
}

if [ "$SCOPE" = "project" ]; then
  # Project settings only matter once committed to a repo, so refuse to scatter
  # a settings.json into an unrelated directory. Write at the repo root, which
  # is where Claude Code reads a project's .claude/settings.json from.
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$REPO_ROOT" ]; then
    echo "install.sh: --project must run inside a git repository (none found at $(pwd))." >&2
    echo "    cd into your project first, or use --user to install for your account." >&2
    exit 2
  fi
  echo "==> installing at PROJECT scope: $REPO_ROOT/.claude/settings.json"
  write_settings "$REPO_ROOT/.claude/settings.json" || exit 1
  write_bootstrap_hook "$REPO_ROOT" || exit 1
  cat <<'MSG'
==> done (project scope). The plugin declaration and the SessionStart bootstrap
    hook are written, but they only take effect once committed:
        git add .claude/settings.json .claude/hooks/install-stack.sh
        git commit -m "Add tokenmaxxxer plugin stack"
    After that, anyone who opens this repo — local CLI, Claude Code on the web,
    and Slack cloud sessions alike — gets the stack installed and enabled on
    session start. Local CLI sessions install from the declarative settings
    (after a one-time trust prompt); remote/web sessions, which run
    non-interactively with no prompt to accept, are installed by the bootstrap
    hook instead. To install for your account machine-wide, re-run with:
    install.sh --user
MSG
  exit 0
fi

# ---- user scope (--user) ---------------------------------------------------

find_cli() {
  if command -v claude >/dev/null 2>&1; then
    command -v claude
    return
  fi
  # The VSCode extension bundles a full CLI; pick the newest version.
  ls -1d "$HOME"/.vscode-server/extensions/anthropic.claude-code-*/resources/native-binary/claude \
         "$HOME"/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude \
         2>/dev/null | sort -V | tail -1
}

CLI=""
[ -z "${TOKENMAXXXER_SETTINGS_ONLY:-}" ] && CLI="$(find_cli)"

if [ -n "$CLI" ] && [ -x "$CLI" ]; then
  echo "==> installing via CLI: $CLI"
  if "$CLI" plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
    echo "    marketplace '$MARKET' already registered"
  else
    "$CLI" plugin marketplace add "$MARKET_SOURCE"
  fi
  "$CLI" plugin marketplace update "$MARKET" >/dev/null 2>&1 || true
  # Install every stack plugin explicitly, then the bundle. The CLI does not
  # auto-install a dependency ADDED to an already-installed bundle, so relying
  # on bundle-side resolution breaks upgrades; explicit installs are idempotent
  # and make "re-run the installer" the fix for every dependency error.
  # A failed install is recorded rather than shrugged off: the closing "installed
  # the full stack" line used to print no matter what happened above it.
  install_failed=""
  for plugin in freelunch terse blueprint no-mock scout no-footgun doctrine warrant dispatch; do
    "$CLI" plugin install "$plugin@$MARKET" --scope user || install_failed="$install_failed $plugin"
  done
  "$CLI" plugin install "$BUNDLE@$MARKET" --scope user || install_failed="$install_failed $BUNDLE"
  # Then update each to the marketplace's latest. `install` on an already-present
  # plugin may no-op, so after the marketplace refresh an explicit `update` is
  # what actually pulls a newer version (e.g. freelunch 0.2.10 -> 0.2.11).
  # Updating the bundle alone would not move its unpinned dependencies, so update
  # each plugin explicitly, same list as the install loop.
  for plugin in freelunch terse blueprint no-mock scout no-footgun doctrine warrant dispatch; do
    "$CLI" plugin update "$plugin@$MARKET" || true
  done
  "$CLI" plugin update "$BUNDLE@$MARKET" || true
  if [ -n "$install_failed" ]; then
    echo "==> FAILED to install:$install_failed"
    echo "    The rest of the stack is installed. Re-run this script — it is idempotent —"
    echo "    or install the failures individually with: $CLI plugin install <name>@$MARKET --scope user"
  else
    echo "==> installed $BUNDLE@$MARKET and the full stack."
  fi
else
  echo "==> no claude CLI found (standalone or bundled): writing user settings directly"
  write_settings "$HOME/.claude/settings.json"
  echo "    the bundle and its dependencies install on next session start"
fi

cat <<'MSG'
==> done (user scope). Start (or reload) a Claude Code session, then:
    - verify with /plugins
    - RECOMMENDED: open /plugin -> marketplaces -> tokenmaxxxer and enable
      auto-update, so future stack additions arrive automatically. There is
      no CLI/config switch for this toggle; it is a one-time interactive step.
    - without auto-update, refresh manually anytime:
      claude plugin update tokenmaxxxer-env@tokenmaxxxer
    - to carry the stack with a repo instead (so cloud/Slack sessions get it too),
      run this from inside that repo with no flag (project scope is the default).
MSG
