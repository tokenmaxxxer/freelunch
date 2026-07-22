# tokenmaxxxer / claude-plugins

A Claude Code plugin marketplace by Jung Jiwon & Lee Jongkwan: a steering stack that makes coding agents faster and cheaper **without lowering the deliverable bar**. Every plugin ships with the benchmark numbers that justify its rules — policies that lose their ablation get removed, not shipped.

The stack's thesis: **no verification anywhere.** Every plugin steers *before* generation — what the field expects, what structure fits, how real it must be, how fast it gets built, how tersely it gets reported. Nothing inspects after. That is what keeps the savings free.

## Why steer, not verify

Verification is the work of closing the gap between an artifact and the *user's oracle* — the standard, usually unstated and often shifting, by which the result will be judged. That oracle moves between turns and frequently sits outside the model's pretrained distribution, so a generating turn cannot reconstruct it. Asking a model to check its own output against an oracle it does not hold is neutral at best, and in the reasoning literature it tends to *degrade* the result — the fused generate–check–repair turn spends a large fixed cost adjudicating a target it can't know, and stalls below it.

So the stack splits the two layers that most harnesses fuse:

- **Generation layer — the agent.** A pure generator, run raw: no self-review, no re-reading, no repair loop. Because every agent draws on the same pretrained distribution they are interchangeable, which is exactly what licenses fanning a task across many cheap equal workers and cutting wall-clock.
- **Verification layer — you.** The oracle lives with the human. Your feedback across rounds *is* the verification procedure.

The economics follow: cheap turns make failure cheap, and **fifty small failures at cost 1 beat one expensive, self-verifying failure at cost 100**. Parallel generation buys speed; human feedback — not the model's self-scrutiny, and not raw agent count (equal agents share blind spots and fail alike) — is what converges the artifact onto the oracle. Steering plugins simply shorten that convergence by moving the generator's *prior* toward the oracle before it writes, never by inspecting the *sample* after. The full argument, with citations and internal measurements, is the position paper [*Generation Is All You Need*](docs/reports/generation-is-all-you-need.md) (Jung & Lee).

The headline measurement — the freelunch plugin's on/off ablation, 18 tasks, 72 headless runs, scored by hidden test scripts:

<img src="docs/_assets/figure-4-ablation-speedup.svg" alt="Measured per-task wall-clock speedup of the parallel-generation plugin across 18 tasks: geometric mean 1.50x, one task slower, quality tied at 630 of 632 checks in both arms" width="700">

Geometric mean **1.50× faster at tied quality** (630/632 checks pass in each arm), with the one task that ran slower under fan-out reported rather than trimmed.

## Install

One line, no clone (works with the standalone CLI or with only the VSCode extension):

```
curl -fsSL https://raw.githubusercontent.com/tokenmaxxxer/claude-plugins/main/install.sh | bash
```

Or from any Claude Code session:

```
/plugin marketplace add tokenmaxxxer/claude-plugins
/plugin install tokenmaxxxer-env@tokenmaxxxer
```

Either way you get the `tokenmaxxxer-env` bundle, whose dependencies pull in the whole stack. One interactive step remains: open `/plugin` → marketplaces → tokenmaxxxer and enable **auto-update**, so future stack additions arrive automatically (there is no CLI switch for this toggle). Individual plugins install the same way: `/plugin install terse@tokenmaxxxer`. If an update ever complains about a missing dependency, re-run the install one-liner — it is idempotent and installs the full stack explicitly.

## Plugins

| Plugin | What it does |
|---|---|
| [freelunch](freelunch/) ⚡ | Estimates a task's *width* (count of independently-producible units) before acting, then runs a lean solo pass for narrow tasks or a fan-out of concurrent background Sonnet agents for wide ones. Measured 1.50x geomean wall-clock speedup at tied quality and lower token cost. |
| [terse](terse/) | Compresses conversational output prose (−38% output tokens measured); code, worker prompts, contracts, and safety-critical text are verbatim zones. Levels via `/terse`. |
| [blueprint](blueprint/) | Sixteen-archetype architecture database with a deterministic classify/recommend CLI; each archetype carries the fan-out contract to freeze before dispatching workers. |
| [no-mock](no-mock/) | Steers deliverables toward production-runnable structure: real persistence and integration seams from the first line, no silent mocks. |
| [scout](scout/) | Pre-build reconnaissance (Camp benchmarking + Kano + saturation stop): finds best-in-class exemplars and the category's must-be baseline, compresses them into a scout brief that steers the build. Measured: restores the must-be features baseline builds systematically omit. |
| [no-footgun](no-footgun/) 🔒 | Direction-only security steering: names the threat patterns for the surface being built (injection, deserialization, XSS, secrets, paths, SSRF, IDOR) so the secure pattern is chosen at write time. Surface-gated, cascading custom rules, zero review passes. Unbenchmarked as of v0.1.0. |
| [doctrine](doctrine/) 📁 | Documentation placement: every document lives in one of six lifetime-based buckets under `docs/` (`decisions/`, `handbooks/`, `reports/`, `specs/`, `proposals/`, `_assets/`). A directive classifies at write time; a `PreToolUse` gate refuses writes that land under `docs/` outside them. Unbenchmarked as of v0.1.0. |
| [warrant](warrant/) 🔒 | Work-unit protocol: a proposal states the request, constraints, and the write set before any code is written; approval freezes that set and the build then runs uninterrupted. A `PreToolUse` gate refuses edits outside the set and commits without the `Proposal:` trailer; `SessionStart` rebuilds state from the repository so an interrupted unit survives the session. At each transition one bounded background hunter probes for silent failures and composition errors on a single stance, returning a reproduced finding or nothing; the proposal and a per-unit hunt record keep what failed and what was probed, so a stranger can resume the work. Unbenchmarked as of v0.4.0. |
| [dispatch](dispatch/) 📡 | Makes git the sole channel between an agent and the oracle above it: every report is a git write, every git event a trigger, so a report *is* the next actor's trigger. Reports route by lifetime (one mutable status surface plus discrete settling points); a needed decision is delivered to the remote as a blocking marker and `awaiting-oracle` label and the run terminates, rather than asking in chat or idling in-process — waiting is remote git state, not a live process. A `PreToolUse` gate holds the oracle boundary (no second decision request, no landing or resolving your own); `SessionStart` rebuilds the parked state from the remote. Unbenchmarked as of v0.1.0. |
| [tokenmaxxxer-env](tokenmaxxxer-env/) | One-install bundle: pulls the whole stack in as dependencies. |

## Team rollout

Commit this to your project's `.claude/settings.json` and everyone who opens the repo gets the stack installed and enabled after a one-time trust prompt. Plugins added to the bundle later reach the team through its version bumps, with no settings change:

```json
{
  "extraKnownMarketplaces": {
    "tokenmaxxxer": {
      "source": { "source": "github", "repo": "tokenmaxxxer/claude-plugins" }
    }
  },
  "enabledPlugins": {
    "tokenmaxxxer-env@tokenmaxxxer": true
  }
}
```

Prefer a subset? Enable individual plugins instead (`"terse@tokenmaxxxer": true`, …).

## Repo layout

- `install.sh` — the one-shot installer described above.
- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `freelunch/`, `terse/`, `blueprint/`, `no-mock/`, `scout/`, `no-footgun/`, `doctrine/`, `warrant/`, `dispatch/`, `tokenmaxxxer-env/` — one directory per plugin, each with its own README and benchmark notes.
- `docs/` — follows the doctrine this repo ships: documents live in lifetime buckets (`reports/` here), attachments in `_assets/`. `experiments/` is a benchmark harness whose markdown is fixture and protocol input, not documentation, so `.claude/settings.json` exempts it via `DOCTRINE_ALLOW`.
