#!/usr/bin/env bash
# Installs the freelunch plugin for Claude Code.
# Prefers a real `claude` CLI (standalone, or the binary bundled inside the
# VSCode extension); falls back to writing ~/.claude/settings.json directly.
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
MARKET="tokenmaxxxer"
PLUGIN="freelunch"

if [ ! -f "$ROOT/.claude-plugin/marketplace.json" ]; then
  echo "ERROR: $ROOT/.claude-plugin/marketplace.json not found — run this script from its repo." >&2
  exit 1
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
[ -z "${FREELUNCH_SETTINGS_ONLY:-}" ] && CLI="$(find_cli)"

if [ -n "$CLI" ] && [ -x "$CLI" ]; then
  echo "==> installing via CLI: $CLI"
  if "$CLI" plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
    echo "    marketplace '$MARKET' already registered"
  else
    "$CLI" plugin marketplace add "$ROOT"
  fi
  "$CLI" plugin install "$PLUGIN@$MARKET" --scope user
  echo "==> installed $PLUGIN@$MARKET (user scope). If VSCode is open, reload the window."
else
  echo "==> no claude CLI found (standalone or bundled): writing settings directly"
  python3 - "$ROOT" "$MARKET" "$PLUGIN" <<'PY'
import json, os, shutil, sys

root, market, plugin = sys.argv[1], sys.argv[2], sys.argv[3]
key = f"{plugin}@{market}"
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

# Marketplace source type for a local path is "directory" (NOT "local" —
# an unknown const fails schema validation and disables the whole file).
settings.setdefault("extraKnownMarketplaces", {})[market] = {
    "source": {"source": "directory", "path": root}
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
  echo "==> done. Reload the VSCode window to activate the plugin."
fi

echo "==> verify inside a Claude Code session with: /plugins"
