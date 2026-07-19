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

**Benchmarked once, no measurable effect at the tested difficulty.** An ON/OFF A/B (8 feature-request tasks, each phrased with zero security language so the vulnerable pattern is the path of least resistance — SQL injection, path traversal, command injection, secret leak, SSRF, XSS, unsafe YAML, IDOR; pre-registered deterministic scorer; Sonnet workers) scored **8/8 secure in both arms**. The Sonnet baseline already picks parameterized queries, argv arrays, `textContent`, `yaml.safe_load`, ownership re-checks, and URL parsing without any prompting — there was no residual insecure selection for the directive to correct. (Two tasks initially read as insecure in both arms; both were scorer false positives, corrected by file inspection.)

This is not evidence the directive is worthless — it is evidence the frontier-model baseline is at ceiling on straightforward single-file tasks, which is also why the incumbent leans on post-generation inspection rather than stronger steering. Where a direction-only directive would plausibly still earn its place, all **untested** here: weaker or smaller worker models; complex contexts where the surrounding contract actively pushes toward the unsafe pattern; and project-specific rules the model cannot infer (the cascading `no-footgun.md`). The mechanics also cost nothing structurally — injected at prompt-assembly time, no extra LLM call — but per-arm wall-clock was not isolated. Data: `experiments/nofootgun-eval-v0.1.json` in the research clone.

---

v0.1.0 — by Jung Jiwon & Lee Jongkwan.
