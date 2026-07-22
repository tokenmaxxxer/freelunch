#!/usr/bin/env bash
# PreToolUse hook (.*): holds the oracle boundary around a decision request.
#
# A decision request parks a unit on the human oracle. It lives as a committed
# `.dispatch/<unit>.decision.md` marker (the git-native truth) plus a PR label.
# While one is open, three things are the oracle's act, not the agent's, and
# this gate refuses them:
#
#   1. opening a SECOND decision request — one unit waits on one question.
#   2. MUTATING an existing marker (Edit) — you do not answer your own request;
#      resolution is the oracle's remote act. A fresh run, triggered by that
#      resolution, removes the marker with `git rm` (not blocked here) and
#      continues.
#   3. LANDING while parked — a `git merge` or a merge_pull_request call while a
#      request is open would land the very unit that is waiting on the oracle.
#
# It reads the TOOL INPUT — a path, a command, a tool name — before anything
# happens. It never reads generated content and makes no judgment about the
# work; whether a decision was warranted is the directive's business.
#
# A marker is "open" when its frontmatter status is not `resolved` (awaiting, or
# absent). Creating the FIRST marker is allowed; that is how a unit parks.
#
# Fails open on a missing python3, unreadable payload, or unexpected schema — a
# broken gate must not be the thing that stops a session.
# Kill switch: export DISPATCH_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${DISPATCH_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat)"

DISPATCH_PAYLOAD="$payload" python3 <<'PY'
import json
import os
import posixpath
import re
import sys

STATUS = re.compile(r"^status:\s*([A-Za-z]+)\s*(?:#.*)?$", re.M)
GIT_MERGE = re.compile(r"\bgit\b(?:\s+-[A-Za-z]\S*(?:\s+\S+)?|\s+--\S+)*\s+merge\b")
# The GitHub MCP tools that land a PR — the merge is the oracle's act.
MERGE_TOOLS = ("mcp__github__merge_pull_request",)


def allow():
    sys.exit(0)


try:
    event = json.loads(os.environ.get("DISPATCH_PAYLOAD", ""))
except ValueError:
    allow()
if not isinstance(event, dict):
    allow()

tool = event.get("tool_name") or ""
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    allow()

root = (os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).replace("\\", "/")
root = posixpath.normpath(root)
# Without CLAUDE_PROJECT_DIR the cwd could be anywhere; anchor on the git root so
# the gate never treats a scratch directory as the project it is guarding.
try:
    import subprocess
    top = subprocess.run(["git", "-C", root, "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, timeout=5).stdout.strip()
    if top:
        root = posixpath.normpath(top.replace("\\", "/"))
    elif not os.environ.get("CLAUDE_PROJECT_DIR"):
        allow()
except (OSError, subprocess.SubprocessError):
    if not os.environ.get("CLAUDE_PROJECT_DIR"):
        allow()

dispatch_dir = posixpath.join(root, ".dispatch")


def frontmatter(path):
    try:
        with open(path, encoding="utf-8-sig") as handle:
            text = handle.read(65536)
    except (OSError, UnicodeDecodeError):
        return None
    if not text.startswith("---"):
        return ""          # a marker without frontmatter is still an open marker
    end = text.find("\n---", 3)
    return text[3:end] if end != -1 else ""


def open_markers(exclude=None):
    """Committed-or-on-disk decision markers whose status is not `resolved`."""
    found = []
    if not os.path.isdir(dispatch_dir):
        return found
    try:
        names = sorted(os.listdir(dispatch_dir))
    except OSError:
        return found
    for name in names:
        if not name.endswith(".decision.md"):
            continue
        full = posixpath.join(dispatch_dir, name)
        if exclude and posixpath.normpath(full) == posixpath.normpath(exclude):
            continue
        block = frontmatter(full)
        if block is None:
            continue
        state = STATUS.search(block)
        if state is None or state.group(1).lower() != "resolved":
            found.append(".dispatch/" + name)
    return found


def refuse(message):
    print("dispatch: refused — " + message, file=sys.stderr)
    sys.exit(2)


# --- landing while parked --------------------------------------------------
if tool in MERGE_TOOLS and open_markers():
    refuse(
        "a decision request is parked on the oracle (%s), and merging is the oracle's act.\n"
        "Landing the unit that is waiting on a question answers it yourself. Leave the merge to me; "
        "your run terminated when it delivered the marker."
        % ", ".join(open_markers()))

if tool == "Bash":
    command = tool_input.get("command")
    if isinstance(command, str) and GIT_MERGE.search(command) and open_markers():
        refuse(
            "a decision request is parked on the oracle (%s), and `git merge` lands the unit that is "
            "waiting on it. Merging is the oracle's remote act, not yours." % ", ".join(open_markers()))
    allow()

# --- marker writes ---------------------------------------------------------
path = tool_input.get("file_path") or tool_input.get("notebook_path")
if not isinstance(path, str) or not path:
    allow()

normalized = path.replace("\\", "/")
absolute = posixpath.normpath(
    normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized))
if not (absolute.endswith(".decision.md") and
        (absolute + "/").startswith(dispatch_dir + "/")):
    allow()          # not a decision marker — nothing for this gate to hold

exists = os.path.exists(absolute)

# Mutating an existing marker is answering your own question. The only write a
# marker ever needs is its first one; after that it is immutable to the agent
# and cleared (by `git rm`, not Edit) on the run the oracle's answer triggers.
if tool in ("Edit", "NotebookEdit") or exists:
    refuse(
        "`%s` already exists — a decision marker is immutable once written. You do not answer, edit, or "
        "resolve your own request; that is the oracle's remote act. The run the answer triggers removes "
        "the marker with `git rm` and continues." % (".dispatch/" + posixpath.basename(absolute)))

# A new marker while another is open is a second question on a unit that already
# waits on one. Park on one thing at a time.
others = open_markers(exclude=absolute)
if others:
    refuse(
        "a decision request is already parked on the oracle (%s). One unit waits on one question — "
        "resolve the open one before parking on another." % ", ".join(others))

allow()
PY

exit $?
