#!/usr/bin/env bash
# Before/after test for the tokenmaxxxer-env router (v0.3.0).
#
# BEFORE = the four standalone hooks, no router marker (the pre-router stack).
# AFTER  = the router's single merged directive, standalone hooks stood down.
#
# Checks: standalone emission intact, router emission complete (all six
# sections), stand-down while the marker is fresh, resume when it goes stale,
# every kill switch, terse level plumbing, and the size delta.
#
# Run: bash tests/hooks_test.sh   (exit 0 = all pass)

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Isolate marker + terse.level from the real user account.
export HOME="$TMP"
mkdir -p "$HOME/.claude"
unset FREELUNCH_OFF NO_MOCK_OFF SCOUT_OFF TERSE_OFF TOKENMAXXXER_OFF || true

HOOKS="freelunch/hooks/freelunch.sh no-mock/hooks/directive.sh scout/hooks/directive.sh terse/hooks/terse.sh"
ROUTER="$ROOT/tokenmaxxxer-env/hooks/router.sh"
MARKER="$HOME/.claude/tokenmaxxxer.router"

pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   $1"; }
bad()  { fail=$((fail+1)); echo "FAIL $1"; }
assert()     { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
has()        { printf '%s' "$1" | grep -q -- "$2"; }

# --- BEFORE: standalone stack, marker absent ---------------------------------
rm -f "$MARKER"
total_before=0
for h in $HOOKS; do
  out="$(bash "$ROOT/$h")"
  n=${#out}
  total_before=$((total_before + n))
  assert "standalone emits: $h (${n} chars)" "[ $n -gt 500 ]"
done

# --- AFTER: router ------------------------------------------------------------
rm -f "$MARKER"
rout="$(bash "$ROUTER")"
total_after=${#rout}
assert "router emits merged directive (${total_after} chars)" "[ $total_after -gt 1000 ]"
assert "router touches marker" "[ -f '$MARKER' ]"
for section in "WIDTH TALLY" "2. SCOUT" "PRODUCTION-RUNNABLE" "4. STRUCTURE" "5. EXECUTE" "6. STYLE"; do
  if has "$rout" "$section"; then ok "router section present: $section"; else bad "router section present: $section"; fi
done
assert "router smaller than standalone sum ($total_after < $total_before)" "[ $total_after -lt $total_before ]"

# --- stand-down: fresh marker silences every standalone hook ------------------
touch "$MARKER"
for h in $HOOKS; do
  out="$(bash "$ROOT/$h")"
  assert "routed, standalone silent: $h" "[ ${#out} -eq 0 ]"
done

# --- resume: stale marker (>24h) brings standalone hooks back -----------------
touch -t 202601010000 "$MARKER"
out="$(bash "$ROOT/freelunch/hooks/freelunch.sh")"
assert "stale marker: standalone resumes" "[ ${#out} -gt 0 ]"
rm -f "$MARKER"

# --- kill switches ------------------------------------------------------------
r="$(TOKENMAXXXER_OFF=1 bash "$ROUTER")"
assert "TOKENMAXXXER_OFF silences router" "[ ${#r} -eq 0 ]"
assert "TOKENMAXXXER_OFF leaves marker untouched" "[ ! -f '$MARKER' ]"

r="$(FREELUNCH_OFF=1 bash "$ROUTER")"
if ! has "$r" "WIDTH TALLY" && ! has "$r" "5. EXECUTE"; then ok "FREELUNCH_OFF drops sections 1+5"; else bad "FREELUNCH_OFF drops sections 1+5"; fi
r="$(SCOUT_OFF=1 bash "$ROUTER")"
if ! has "$r" "2. SCOUT"; then ok "SCOUT_OFF drops section 2"; else bad "SCOUT_OFF drops section 2"; fi
r="$(NO_MOCK_OFF=1 bash "$ROUTER")"
if ! has "$r" "PRODUCTION-RUNNABLE"; then ok "NO_MOCK_OFF drops section 3"; else bad "NO_MOCK_OFF drops section 3"; fi
r="$(TERSE_OFF=1 bash "$ROUTER")"
if ! has "$r" "6. STYLE"; then ok "TERSE_OFF drops section 6"; else bad "TERSE_OFF drops section 6"; fi

# --- terse level plumbing -----------------------------------------------------
echo off > "$HOME/.claude/terse.level"
r="$(bash "$ROUTER")"
if ! has "$r" "6. STYLE"; then ok "terse.level=off drops section 6"; else bad "terse.level=off drops section 6"; fi
echo ultra > "$HOME/.claude/terse.level"
r="$(bash "$ROUTER")"
if has "$r" "LEVEL ultra"; then ok "terse.level=ultra reflected"; else bad "terse.level=ultra reflected"; fi
rm -f "$HOME/.claude/terse.level"

# --- summary ------------------------------------------------------------------
echo "----"
echo "before (4 standalone directives): ${total_before} chars/prompt"
echo "after  (1 merged directive):      ${total_after} chars/prompt"
echo "delta: $(( (total_before - total_after) * 100 / total_before ))% smaller"
echo "passed ${pass}, failed ${fail}"
[ "$fail" -eq 0 ]
