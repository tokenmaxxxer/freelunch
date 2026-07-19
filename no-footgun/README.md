# no-footgun 🔒

Direction-only security steering for Claude Code: a `UserPromptSubmit` hook that names the threat patterns relevant to the surface being built — injection, unsafe deserialization, XSS, secret handling, path traversal, SSRF, IDOR, error leakage, hand-rolled crypto — so the secure pattern is chosen **at write time**. No review passes, no scans, no re-reads: prevention happens at pattern choice, which is why it costs nothing but the directive's reading time.

## Where it sits in the field

Scouted before building (2026-07-20):

- Anthropic's official [`security-guidance`](https://github.com/anthropics/claude-code/tree/main/plugins/security-guidance) plugin owns the **inspection** segment: regex pattern warnings on edits, an LLM diff review on every Stop hook, and an agentic commit review — effective (30-40% fewer security PR comments in their rollout), but every layer is a post-generation check with real latency and API cost, which is exactly what this stack's no-verification philosophy excludes.
- The [OpenSSF Security-Focused Guide for AI Code Assistant Instructions](https://best.openssf.org/Security-Focused-Guide-for-AI-Code-Assistant-Instructions.html) owns the **instruction-only** segment and supplies this plugin's evidence base: rules should be concise, specific, and actionable; persona framing ("act as a security expert") measurably underperforms explicit rules; and irrelevant rules actively degrade generation — the reason this directive is surface-gated.

no-footgun takes the incumbent's one transferable pattern — a cascading custom-rules file — and the OpenSSF instruction style, and ships them as an always-on direction with zero inspection layers.

## How it works

- **Surface gate first**: the directive applies only when the deliverable touches untrusted input, secrets, subprocess/shell, SQL, HTML rendering, deserialization, runtime-built paths or URLs, or authn/authz. Pure algorithms, styling, docs: inert, zero behavioral change.
- **Pattern steering, not checking**: each rule says what to write ("parameterized queries", "argument arrays, shell=False", "textContent, not innerHTML", "env vars + .env.example"), never "verify afterward that…".
- **Custom rules cascade**: `~/.claude/no-footgun.md` (user-wide) and `./.claude/no-footgun.md` (project, committed) are appended verbatim with the same force — the place for rules the model can't infer ("all customer-table reads go through the replica").
- **Composes with the stack**: fan-out worker task specs (freelunch) inherit the gate verdict and applicable rules; workers still deliver raw. Deep threat enumeration stays with the `stride` skill, invoked deliberately — this hook only steers pattern choice.

## Install

```
/plugin install no-footgun@tokenmaxxxer
```

## Temporarily disable

```
export NO_FOOTGUN_OFF=1
```

## Honest status

**Unbenchmarked.** The rule content tracks OWASP/OpenSSF consensus and the incumbent's ~25-pattern taxonomy, and the directive mechanics (surface gate, direction-only, worker inheritance) reuse structures measured elsewhere in this stack — but no A/B has yet measured whether this directive raises secure-pattern selection rates or what it costs on the dom-infra-style short-task tail. The planned protocol exists: vulnerability-prone task prompts, ON/OFF arms, pre-registered vulnerability checklist scoring, same harness as the freelunch evals.

---

v0.1.0 — by Jung Jiwon & Lee Jongkwan.
