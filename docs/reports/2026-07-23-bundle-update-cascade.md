# Does `claude plugin update tokenmaxxxer-env@tokenmaxxxer` cascade updates to its dependency plugins?

**Date:** 2026-07-23
**CLI version:** `claude` 2.1.218 (`/opt/node22/bin/claude`)
**Method:** empirical, isolated sandbox HOME, not touching this repo's own Claude state.

## Conclusion

**No — bundle-only update does NOT cascade to dependency plugins.** Running
`claude plugin update tokenmaxxxer-env@tokenmaxxxer` only checks/updates the
bundle plugin itself. A dependency that was pinned to a stale version/commit
in `installed_plugins.json` was left completely untouched by the bundle
update, and only changed when updated explicitly
(`claude plugin update freelunch@tokenmaxxxer`). If a user installs only the
bundle and later runs update on only the bundle, the 9 dependency plugins do
**not** get refreshed — they require their own explicit
`claude plugin update <dep>@tokenmaxxxer` calls (or `claude plugin update`
with no args, which updates everything).

## Setup

Isolated sandbox to avoid touching this repo or its plugin state:

```bash
SCRATCH=/tmp/claude-0/-home-user-claude-plugins/af17a59b-1ac3-5772-9263-82d778f2baec/scratchpad
rm -rf "$SCRATCH/cascade-home"
mkdir -p "$SCRATCH/cascade-home"
export HOME="$SCRATCH/cascade-home"
cd /tmp   # non-repo cwd, so nothing writes into a repo's .claude/settings.json
```

`claude` binary used: `/opt/node22/bin/claude` (`command -v claude` resolves
to the same path), version `2.1.218`.

## Step 1 — register the marketplace and install only the bundle

```bash
/opt/node22/bin/claude plugin marketplace add /home/user/claude-plugins
```

Output:

```
Adding marketplace…√ Successfully added marketplace: tokenmaxxxer (declared in user settings)
```

```bash
/opt/node22/bin/claude plugin install tokenmaxxxer-env@tokenmaxxxer --scope user
```

Output:

```
Installing plugin "tokenmaxxxer-env@tokenmaxxxer"...√ Successfully installed plugin: tokenmaxxxer-env@tokenmaxxxer (scope: user) (+ 9 dependencies: freelunch, terse, blueprint, no-mock, scout, …)
```

Confirms the install-cascade half already works: installing the bundle alone
pulled in all 9 declared bare-name dependencies automatically, each recorded
in `installed_plugins.json` with `"auto": true`.

Versions recorded immediately after install (from
`$HOME/.claude/plugins/installed_plugins.json`):

| Plugin | Version | auto |
|---|---|---|
| tokenmaxxxer-env | 0.6.0 | (bundle itself) |
| freelunch | 0.2.18 | true |
| terse | 0.2.7 | true |
| blueprint | 0.2.0 | true |
| no-mock | 0.2.3 | true |
| scout | 0.1.4 | true |
| no-footgun | 0.1.3 | true |
| doctrine | 0.4.3 | true |
| warrant | 0.4.0 | true |
| dispatch | 0.5.0 | true |

All 10 entries shared the same `gitCommitSha`
(`7e5f48ffab8b085aeb6da819c782216994ee53a8`), i.e. the marketplace repo's
current commit at install time.

## Step 2 — simulate a stale dependency

The marketplace only ever serves the current version of each plugin (there's
no older-version registry to install from), so a genuine stale state can't be
produced by installing an old release. Instead the "already installed but
stale" condition was fabricated directly, the way a real stale record would
look on disk after time passed and the marketplace source moved on:

1. Duplicated the cached `freelunch` plugin directory to a fabricated
   older-version path:
   ```bash
   CACHE="$HOME/.claude/plugins/cache/tokenmaxxxer"
   cp -r "$CACHE/freelunch/0.2.18" "$CACHE/freelunch/0.2.0"
   sed -i 's/"version": "0.2.18"/"version": "0.2.0"/' \
     "$CACHE/freelunch/0.2.0/.claude-plugin/plugin.json"
   ```
2. Rewrote the `freelunch@tokenmaxxxer` entry in `installed_plugins.json` to
   point at that fabricated old directory/version, with an old timestamp and
   a fake (all-zero) `gitCommitSha` standing in for "installed a long time
   ago, marketplace has since moved on":
   ```json
   "freelunch@tokenmaxxxer": [
     {
       "scope": "user",
       "installPath": ".../cache/tokenmaxxxer/freelunch/0.2.0",
       "version": "0.2.0",
       "installedAt": "2026-01-01T00:00:00.000Z",
       "lastUpdated": "2026-01-01T00:00:00.000Z",
       "gitCommitSha": "0000000000000000000000000000000000000000",
       "auto": true
     }
   ]
   ```

Confirmed before running any update that this fabricated stale state was in
place (version `0.2.0`, fake commit sha, old timestamps).

## Step 3 — run the bundle-only update and observe

```bash
/opt/node22/bin/claude plugin update tokenmaxxxer-env@tokenmaxxxer
```

Full stdout/stderr:

```
Checking for updates for plugin "tokenmaxxxer-env@tokenmaxxxer" at user scope…
√ tokenmaxxxer-env is already at the latest version (0.6.0).
```

Exit code: `0`. The output mentions **only** the bundle plugin
(`tokenmaxxxer-env`, version `0.6.0`) — it never names, checks, or touches
`freelunch` or any of the other 8 dependencies.

`installed_plugins.json`'s `freelunch@tokenmaxxxer` entry immediately after
this command — **byte-for-byte unchanged** from the fabricated stale state:

```json
[
  {
    "scope": "user",
    "installPath": ".../cache/tokenmaxxxer/freelunch/0.2.0",
    "version": "0.2.0",
    "installedAt": "2026-01-01T00:00:00.000Z",
    "lastUpdated": "2026-01-01T00:00:00.000Z",
    "gitCommitSha": "0000000000000000000000000000000000000000",
    "auto": true
  }
]
```

The stale `freelunch` was left at fabricated version `0.2.0` — the bundle
update did not re-resolve, re-fetch, or re-point it at the marketplace's
actual current version (`0.2.18`).

## Step 4 — contrast with an explicit per-dependency update

```bash
/opt/node22/bin/claude plugin update freelunch@tokenmaxxxer
```

Full stdout/stderr:

```
Checking for updates for plugin "freelunch@tokenmaxxxer" at user scope…
√ Plugin "freelunch" updated from 0.2.0 to 0.2.18 for scope user. Restart to apply changes.
```

`installed_plugins.json`'s `freelunch@tokenmaxxxer` entry afterward:

```json
[
  {
    "scope": "user",
    "installPath": ".../cache/tokenmaxxxer/freelunch/0.2.18",
    "version": "0.2.18",
    "installedAt": "2026-01-01T00:00:00.000Z",
    "lastUpdated": "2026-07-23T02:20:16.191Z",
    "gitCommitSha": "7e5f48ffab8b085aeb6da819c782216994ee53a8",
    "auto": true
  }
]
```

Explicitly targeting the dependency correctly detected the stale
`0.2.0` → resolved to the marketplace's real current `0.2.18`, updated
`installPath`, `gitCommitSha`, and `lastUpdated`. This is the exact repair
that the bundle-only update (Step 3) failed to perform on the same stale
record.

## Evidence summary

| Command run | What it touched | freelunch version before → after |
|---|---|---|
| `claude plugin update tokenmaxxxer-env@tokenmaxxxer` | only the bundle entry; output never mentions any dependency | `0.2.0` → `0.2.0` (no change) |
| `claude plugin update freelunch@tokenmaxxxer` | the named dependency only | `0.2.0` → `0.2.18` (repaired) |

This directly answers the question: if a user installs only the bundle and
later runs `claude plugin update` on only the bundle name, the 9 dependency
plugins are **not** refreshed. They will silently stay pinned to whatever
version they were auto-installed at (or later drift to) until each is
updated individually — or until `claude plugin update` is run with no
argument at all (untested here; out of scope for this investigation, which
targeted the bundle-name-only case exactly as asked).

## Caveat on the staleness simulation

Because the marketplace here only ever serves the single current commit of
each plugin, there is no way to reproduce "the marketplace pushed a new
release and the user's dependency is now stale" via a real second release.
The stale record was therefore fabricated by hand-editing
`installed_plugins.json` and duplicating the cache directory under a fake
old-version path. This reproduces exactly what a genuinely stale on-disk
record looks like (mismatched version, mismatched `installPath`, an older
`gitCommitSha`), and the bundle-update command's behavior against that
fabricated record was identical either way it would arise: it does not
inspect or repair dependency entries at all — its own output text and the
untouched JSON are conclusive on that point regardless of how the staleness
was produced.

## Cleanup

```bash
rm -rf "$SCRATCH/cascade-home"
```

Sandbox HOME removed at the end; the real repo and its `.claude` state were
never touched by any `claude plugin`/`claude plugin marketplace` command in
this investigation (only read via `cat` for the dependency list).
