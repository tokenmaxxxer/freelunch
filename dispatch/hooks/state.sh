#!/usr/bin/env bash
# SessionStart hook: rebuilds dispatch state from the remote.
#
# The point of delivering the parked state to the remote is that a new session —
# or a stranger's clone — can see who is waiting on whom without being told. This
# fetches, reads the committed `.dispatch/<unit>.decision.md` markers, and says
# which units are parked on the oracle. It writes nothing.
#
# It reads the REMOTE-delivered state, not a live process: a marker is real
# because it was committed and pushed, so a run that idled locally without
# pushing leaves nothing here — which is the point.
# Kill switch: export DISPATCH_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${DISPATCH_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0
[ -d "$root/.dispatch" ] || exit 0

branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)"

# Best-effort: the parked state lives on the remote, so refresh before reading it.
# Never block the session on the network — a short timeout, failure ignored.
timeout 10 git -C "$root" fetch --quiet 2>/dev/null || true

DISPATCH_ROOT="$root" DISPATCH_BRANCH="$branch" python3 <<'PY'
import os
import re
import sys

root = os.environ["DISPATCH_ROOT"]
branch = os.environ.get("DISPATCH_BRANCH", "")
dispatch_dir = os.path.join(root, ".dispatch")

STATUS = re.compile(r"^status:\s*([A-Za-z]+)\s*(?:#.*)?$", re.M)
QUESTION = re.compile(r"^(?:QUESTION|question):\s*(.+)$", re.M)


def read(path):
    try:
        with open(path, encoding="utf-8-sig") as handle:
            return handle.read(65536)
    except (OSError, UnicodeDecodeError):
        return None


parked = []
for name in sorted(os.listdir(dispatch_dir)):
    if not name.endswith(".decision.md"):
        continue
    text = read(os.path.join(dispatch_dir, name))
    if text is None:
        continue
    block = text[3:text.find("\n---", 3)] if text.startswith("---") else ""
    state = STATUS.search(block)
    if state is not None and state.group(1).lower() == "resolved":
        continue
    q = QUESTION.search(text)
    parked.append((".dispatch/" + name, q.group(1).strip() if q else ""))

if not parked:
    sys.exit(0)

lines = ["dispatch: units parked on the oracle in this repository —"]
for path, question in parked:
    tail = (" — \"%s\"" % question) if question else ""
    lines.append(
        "  AWAITING ORACLE: %s%s. This unit is waiting on a decision; do not resume its work until the "
        "oracle answers on the remote. If you are that answer's run, read it, remove the marker with "
        "`git rm`, and continue." % (path, tail))
lines.append("  (branch %s)" % (branch or "?"))
print("\n".join(lines))
PY

exit 0
