#!/usr/bin/env bash
# PreToolUse hook (.*): keeps work attached to its unit and keeps dispatch state
# on the bus.
#
# Two mechanical checks, both on the TOOL INPUT, both inert unless the repository
# has opted into dispatch by having a `.dispatch/` directory:
#
#   1. On a feature branch, a commit carries a `Dispatch: <branch>` trailer, so
#      `git log --grep 'Dispatch: <branch>'` answers "what shipped for this unit"
#      even after the branch is gone or the commits are cherry-picked — the same
#      trick warrant's `Proposal:` trailer plays, keyed to the unit rather than
#      the proposal. On the default branch (main/master) or a detached HEAD there
#      is no unit, so the check is inert.
#
#   2. dispatch's own state — the live-status surface and decision markers under
#      `.dispatch/` — is written THROUGH the file tools and committed, never poked
#      by shell redirection. A `>> .dispatch/...` or `tee`/`sed -i` into that
#      directory routes around the path-based gates and around git; it is refused
#      so the state stays on the bus, visible and committable.
#
# It makes no judgment about the work or the report's content — whether a report
# should have been a comment or a surface edit is the directive's business.
#
# Fails open on a missing python3, unreadable payload, or unexpected schema.
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
import subprocess
import sys

GIT_COMMIT = re.compile(r"\bgit\b(?:\s+-[A-Za-z]\S*(?:\s+\S+)?|\s+--\S+)*\s+commit\b")
REDIRECT = re.compile(r"(?<![0-9&])>{1,2}(?![&|])")
TEE = re.compile(r"\btee\b")
SED_I = re.compile(r"\b(sed|perl|ruby)\b[^|]*\s-i\b")
DEFAULT_BRANCHES = ("main", "master", "HEAD")


def allow():
    sys.exit(0)


try:
    event = json.loads(os.environ.get("DISPATCH_PAYLOAD", ""))
except ValueError:
    allow()
if not isinstance(event, dict):
    allow()

tool = event.get("tool_name") or ""
if tool != "Bash":
    allow()
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    allow()
command = tool_input.get("command")
if not isinstance(command, str) or not command.strip():
    allow()

root = (os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).replace("\\", "/")
root = posixpath.normpath(root)
try:
    top = subprocess.run(["git", "-C", root, "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, timeout=5).stdout.strip()
    if top:
        root = posixpath.normpath(top.replace("\\", "/"))
    elif not os.environ.get("CLAUDE_PROJECT_DIR"):
        allow()
except (OSError, subprocess.SubprocessError):
    if not os.environ.get("CLAUDE_PROJECT_DIR"):
        allow()

# Inert until the repository opts in by having a `.dispatch/` directory.
if not os.path.isdir(posixpath.join(root, ".dispatch")):
    allow()

# State under `.dispatch/` is written through the file tools and committed, not
# poked around the bus by shell.
if ".dispatch/" in command and (REDIRECT.search(command) or TEE.search(command) or SED_I.search(command)):
    print(
        "dispatch: refused — writing dispatch state under `.dispatch/` by shell goes around the bus.\n"
        "The live-status surface and decision markers are written with the file tools and committed, so "
        "the path gates see them and git carries them. Use Write/Edit, then commit.",
        file=sys.stderr)
    sys.exit(2)

if not GIT_COMMIT.search(command):
    allow()

try:
    branch = subprocess.run(["git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD"],
                            capture_output=True, text=True, timeout=5).stdout.strip()
except (OSError, subprocess.SubprocessError):
    allow()

# No unit on the default branch or a detached HEAD — nothing to attach to.
if not branch or branch in DEFAULT_BRANCHES:
    allow()

trailer = "Dispatch: " + branch
if trailer in command:
    allow()

print(
    "dispatch: refused — this commit carries no unit trailer.\n"
    "Work on branch `%s` is a dispatch unit, so every commit ends with:\n"
    "    %s\n"
    "Add the trailer as the last line of the commit message; `git log --grep '%s'` then answers what "
    "shipped for this unit. (On main/master the check is inert; export DISPATCH_OFF=1 to disable.)"
    % (branch, trailer, trailer),
    file=sys.stderr)
sys.exit(2)
PY

exit $?
