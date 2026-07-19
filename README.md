# tokenmaxxxer / claude-plugins

A Claude Code plugin marketplace by Jung Jiwon & Lee Jongkwan: a steering stack that makes coding agents faster and cheaper **without lowering the deliverable bar**. Every plugin ships with the benchmark numbers that justify its rules — policies that lose their ablation get removed, not shipped.

The stack's thesis: **no verification anywhere.** Every plugin steers *before* generation — what the field expects, what structure fits, how real it must be, how fast it gets built, how tersely it gets reported. Nothing inspects after. That is what keeps the savings free.

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

Either way you get the `tokenmaxxxer-env` bundle, whose dependencies pull in the whole stack. One interactive step remains: open `/plugin` → marketplaces → tokenmaxxxer and enable **auto-update**, so future stack additions arrive automatically (there is no CLI switch for this toggle). Individual plugins install the same way: `/plugin install terse@tokenmaxxxer`.

## Plugins

| Plugin | What it does |
|---|---|
| [freelunch](freelunch/) ⚡ | Estimates a task's *width* (count of independently-producible units) before acting, then runs a lean solo pass for narrow tasks or a fan-out of concurrent background Sonnet agents for wide ones. Measured 1.50x geomean wall-clock speedup at tied quality and lower token cost. |
| [terse](terse/) | Compresses conversational output prose (−38% output tokens measured); code, worker prompts, contracts, and safety-critical text are verbatim zones. Levels via `/terse`. |
| [blueprint](blueprint/) | Sixteen-archetype architecture database with a deterministic classify/recommend CLI; each archetype carries the fan-out contract to freeze before dispatching workers. |
| [no-mock](no-mock/) | Steers deliverables toward production-runnable structure: real persistence and integration seams from the first line, no silent mocks. |
| [scout](scout/) | Pre-build reconnaissance (Camp benchmarking + Kano + saturation stop): finds best-in-class exemplars and the category's must-be baseline, compresses them into a scout brief that steers the build. Measured: restores the must-be features baseline builds systematically omit. |
| [tokenmaxxxer-env](tokenmaxxxer-env/) | One-install bundle: pulls the whole stack in as dependencies, and its router hook merges the four per-plugin directives into one per-prompt injection (12,095 → 6,544 chars, −46%); standalone hooks stand down via a marker file while the router is active, and resume automatically if the bundle is removed. |

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
- `tests/hooks_test.sh` — before/after test for the router: standalone emission, merged emission, stand-down/resume, kill switches, size delta.
- `freelunch/`, `terse/`, `blueprint/`, `no-mock/`, `scout/`, `tokenmaxxxer-env/` — one directory per plugin, each with its own README and benchmark notes.
