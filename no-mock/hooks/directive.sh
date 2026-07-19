#!/usr/bin/env bash
# UserPromptSubmit hook: injects the production-direction steering directive.
#
# v0.2.0 (2026-07-19): no-mock is a STEERING plugin, not a verification plugin.
# v0.1.0 shipped a Stop-hook proof.sh gate and a post-write mock sniffer; both
# were removed — checking after the fact is verification machinery, and the
# stack's philosophy (freelunch) already rejects verification passes. What
# remains is direction-setting at generation time: build the production-capable
# structure from the start, so there is nothing to catch later.
# Kill switch: export NO_MOCK_OFF=1

if [ -n "$NO_MOCK_OFF" ]; then
  exit 0
fi

# Routed mode (v0.2.1): when the tokenmaxxxer-env router hook is active it
# emits the merged stack directive (this plugin's rules included), so the
# standalone injection stands down. The router touches this marker on every
# prompt; a marker older than a day means the router is gone — resume.
ROUTER_MARKER="${HOME}/.claude/tokenmaxxxer.router"
if [ -f "$ROUTER_MARKER" ] && [ -n "$(find "$ROUTER_MARKER" -mmin -1440 2>/dev/null)" ]; then
  exit 0
fi

cat <<'EOF'
<no-mock-directive priority="high">
This directive steers HOW you build, before you build. It adds no checks, no gates, and no extra runs — it sets the default target: what the user asked for, built as a structure that can actually run in production.

BIND TO INTENT FIRST: read what the deliverable is FOR. A product, service, or tool the user will actually use or sell targets production-runnable by default. Only an explicitly-requested demo, sketch, or throwaway targets less. When intent is ambiguous, assume production.

BUILD THE REAL PATH FROM THE START — direction, not inspection:
- Persistence is real persistence: when the deliverable stores data, wire the declared store (with its schema/migrations) from the first line — never an in-memory stand-in "to be replaced later", never route handlers returning fixtures.
- Integrations are real seams: call the actual client/SDK with config read from the environment (ship a .env.example naming every variable). If a credential is missing, still build the real seam and say plainly which variable makes it live — do not reroute around the integration.
- Errors surface: failures propagate to the caller/log with cause; no swallowed exceptions to keep a demo green, no fake success paths.
- The structure is complete for its purpose: if the user asked for an app, that includes the backend it needs; a frontend calling nothing is scenery, not an app.

NO SILENT DOWNGRADE: never quietly substitute a mock because the real path is inconvenient. A placeholder is allowed only when the user asked for one or it is genuinely unavoidable — and then it is labeled: MOCK in the reply, a `MOCK:` comment at the site, and every mocked seam listed in the final message with what would make it real.

HONEST CLAIMS: say "runs" or "works" only about things you actually ran (show the output you already have); otherwise state plainly what was built but not executed. This restricts claims — it never mandates extra runs to earn them.

SCOPE: direction only. This never adds verification passes, review loops, or test obligations, and it never overrides orchestration directives (freelunch) — workers inherit the same direction through their task specs and still deliver raw.
</no-mock-directive>
EOF
exit 0
