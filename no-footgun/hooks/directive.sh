#!/usr/bin/env bash
# UserPromptSubmit hook: injects the security-direction directive into context on every prompt.
#
# v0.1.0 (2026-07-20): direction-only security steering — the secure pattern is
# chosen BEFORE generation; nothing is scanned, reviewed, or re-read after.
# Scouted against the field before building (see README): Anthropic's official
# security-guidance plugin owns the inspection segment (regex warnings -> Stop-hook
# LLM diff review -> agentic commit review; real latency and API cost per layer);
# the OpenSSF Security-Focused Guide for AI Code Assistant Instructions owns the
# instruction-only segment and supplies the evidence base for this directive's
# style: concise/specific/actionable rules, no persona framing (measured to
# perform poorly), and a relevance gate because irrelevant rules degrade
# generation. Adopted from the incumbent: the cascading custom-rules file.
# Rejected: every post-generation inspection layer.
#
# Custom rules cascade (appended verbatim under PROJECT RULES when present):
#   ~/.claude/no-footgun.md          user-wide
#   ./.claude/no-footgun.md          project (committed)
#
# To disable: export NO_FOOTGUN_OFF=1

if [ -n "$NO_FOOTGUN_OFF" ]; then
  exit 0
fi

cat <<'EOF'
<no-footgun-directive priority="high">
This directive steers WHICH patterns you reach for, before generation. It adds no checks, no review passes, and no extra runs — the secure pattern is chosen at write time, never inspected afterward.

SURFACE GATE: apply this directive only when the deliverable touches at least one of: untrusted input (user/network/file-derived), secrets or credentials, subprocess or shell execution, SQL or query construction, HTML rendering, deserialization, file paths built from runtime values, outbound requests to runtime-determined URLs, or authn/authz. If none apply — pure algorithms, styling, docs, build config without secrets — this directive is inert: skip it entirely and write nothing differently. Irrelevant security rules degrade generation; the gate is load-bearing.

THREAT-PATTERN STEERING (write it safely the first time):
- Injection: never build SQL, shell, or OS commands by concatenating runtime values — parameterized queries; subprocess with argument arrays (shell=False / no sh -c); no eval, exec, or new Function on anything derived from runtime input.
- Deserialization: no pickle.load, yaml.load (unsafe), or torch.load(weights_only=False) on data crossing a trust boundary — yaml.safe_load, JSON, or schema-validated formats.
- XSS/DOM: untrusted data never reaches innerHTML, dangerouslySetInnerHTML, or document.write — textContent or the framework's escaped rendering path.
- Secrets: credentials, keys, and tokens live in environment variables only (ship .env.example naming each one); never in source, logs, error messages, or URLs; compare secrets constant-time.
- Paths: any filesystem path containing a runtime value is resolved and prefix-checked against its intended root before use.
- Outbound requests: runtime-determined URLs go through an allow-list or pinned host set (SSRF); TLS verification is never disabled.
- AuthZ: every non-public route or handler checks authorization explicitly — default deny; object-level access re-checks ownership (IDOR), not just authentication.
- Errors: callers get generic messages; details and stack traces go to logs — internals never cross the trust boundary. This narrows no-mock's errors-surface rule at security boundaries; both hold: propagate fully to logs, disclose minimally to callers.
- Crypto and dependencies: platform/stdlib crypto only, never hand-rolled; no new dependency for what the platform already provides; pin versions; never suggest a package you are not certain exists.

PROJECT RULES: rules appended below this directive (from ~/.claude/no-footgun.md or ./.claude/no-footgun.md) carry the same force as the list above.

COMPOSITION: this is a direction, so it travels like one — fan-out worker task specs inherit the gate verdict and the applicable rules (freelunch workers write to the same standard and still deliver raw, unreviewed). It never overrides orchestration.

NEVER:
- a security review pass, scan, diff audit, or re-read of finished code — prevention happens at pattern choice; zero post-hoc steps is the design, not an omission.
- persona framing ("act as a security expert") — state the rule, not the role; personas measurably underperform explicit instructions.
- applying the rule list to surfaces the gate excludes.
- inline threat modeling — when a task needs systematic threat enumeration, that is the stride skill, invoked deliberately; this hook only steers pattern choice.
</no-footgun-directive>
EOF

for f in "$HOME/.claude/no-footgun.md" "./.claude/no-footgun.md"; do
  if [ -f "$f" ]; then
    echo "<no-footgun-project-rules src=\"$f\">"
    cat "$f"
    echo "</no-footgun-project-rules>"
  fi
done

exit 0
