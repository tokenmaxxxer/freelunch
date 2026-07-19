# tokenmaxxxer / claude-plugins

A Claude Code plugin marketplace by Jung Jiwon & Lee Jongkwan. Every plugin here ships with the benchmark numbers that justify its rules — policies that lost their ablation get removed, not shipped.

The stack's thesis: **no verification anywhere** — every plugin steers before generation; none inspects after. That is what keeps the savings free.

## Plugins

| Plugin | What it does |
|---|---|
| [freelunch](freelunch/) ⚡ | Estimates a task's *width* (count of independently-producible units) before acting, then runs a lean solo pass for narrow tasks or a fan-out of concurrent background Sonnet agents for wide ones. Measured 1.50x geomean wall-clock speedup at tied quality and lower token cost. |
| [terse](terse/) | Compresses conversational output prose (−38% output tokens measured); code, worker prompts, contracts, and safety-critical text are verbatim zones. Levels via `/terse`. |
| [blueprint](blueprint/) | Sixteen-archetype architecture database with a deterministic classify/recommend CLI; each archetype carries the fan-out contract to freeze before dispatching workers. |
| [no-mock](no-mock/) | Steers deliverables toward production-runnable structure: real persistence and integration seams from the first line, no silent mocks. |
| [scout](scout/) | Pre-build reconnaissance (Camp benchmarking + Kano + saturation stop): finds best-in-class exemplars and the category's must-be baseline, compresses them into a scout brief that steers the build. Measured: restores the must-be features baseline builds systematically omit. |
| [tokenmaxxxer-env](tokenmaxxxer-env/) | One-install bundle: pulls the whole stack in as dependencies. |

## Install everything (one bundle)

Inside any Claude Code CLI session:

```
/plugin marketplace add tokenmaxxxer/claude-plugins
/plugin install tokenmaxxxer-env@tokenmaxxxer
```

Or from a shell:

```
claude plugin marketplace add tokenmaxxxer/claude-plugins
claude plugin install tokenmaxxxer-env@tokenmaxxxer
```

Installing the bundle resolves and installs every dependency automatically. Individual plugins install the same way (`/plugin install terse@tokenmaxxxer`, …).

## Team rollout (auto-install for a whole repo)

Commit this to your project's `.claude/settings.json` and everyone who opens the repo gets the whole stack installed and enabled after a one-time trust prompt — enabling the bundle pulls in and enables every dependency, and plugins added to the bundle later reach the team through its version bumps with no settings change:

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

Using only the VSCode extension (its chat has no `/plugin` commands)? Each plugin directory ships an `install.sh` that finds the CLI bundled inside the extension and installs through it — see the plugin's README for details.

## Repo layout

- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `freelunch/` — the plugin itself (hooks, agents, workflows), plus its README and installer.
- `docs/`, `experiments/` — the freelunch benchmark suite, results, and paper.
