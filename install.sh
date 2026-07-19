#!/usr/bin/env bash
# One-shot installer for the tokenmaxxxer stack.
# Registers the marketplace, installs the tokenmaxxxer-env bundle (which pulls
# every plugin in as a dependency), and refreshes the marketplace once.
# Prefers a real `claude` CLI (standalone, or the binary bundled inside the
# VSCode extension); falls back to writing ~/.claude/settings.json directly.
#
# Marketplace source: the local checkout when this script runs from the repo,
# otherwise the GitHub repo — so a standalone copy of this script also works.
set -u

MARKET="tokenmaxxxer"
BUNDLE="tokenmaxxxer-env"
GITHUB_REPO="tokenmaxxxer/claude-plugins"

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/.claude-plugin/marketplace.json" ]; then
  MARKET_SOURCE="$SCRIPT_DIR"
  SETTINGS_SOURCE_JSON="{\"source\": \"directory\", \"path\": \"$SCRIPT_DIR\"}"
else
  MARKET_SOURCE="$GITHUB_REPO"
  SETTINGS_SOURCE_JSON="{\"source\": \"github\", \"repo\": \"$GITHUB_REPO\"}"
fi

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
  "$CLI" plugin install "$BUNDLE@$MARKET" --scope user
  "$CLI" plugin marketplace update "$MARKET" >/dev/null 2>&1 || true
  echo "==> installed $BUNDLE@$MARKET — its dependencies (the whole stack) install automatically."
else
  echo "==> no claude CLI found (standalone or bundled): writing settings directly"
  python3 - "$MARKET" "$BUNDLE" "$SETTINGS_SOURCE_JSON" <<'PY'
import json, os, shutil, sys

market, bundle, source_json = sys.argv[1], sys.argv[2], sys.argv[3]
key = f"{bundle}@{market}"
path = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(path), exist_ok=True)

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
print(f"    updated {path} — the bundle and its dependencies install on next session start")
PY
fi

cat <<'MSG'
==> done. Start (or reload) a Claude Code session, then:
    - verify with /plugins
    - RECOMMENDED: open /plugin -> marketplaces -> tokenmaxxxer and enable
      auto-update, so future stack additions arrive automatically. There is
      no CLI/config switch for this toggle; it is a one-time interactive step.
    - without auto-update, refresh manually anytime:
      claude plugin update tokenmaxxxer-env@tokenmaxxxer
MSG
