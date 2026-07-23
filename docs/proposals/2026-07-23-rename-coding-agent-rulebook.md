---
status: approved
files:
  - README.md
  - install.sh
  - freelunch/README.md
---

# Rename repo: claude-plugins → coding-agent-rulebook

Issue: #26

## Request
Rename the repository from `claude-plugins` to `coding-agent-rulebook`. The old name only says "these are Claude plugins"; the new name says what they actually are — a rulebook of behavioral directives that govern how a coding agent works.

## Constraints that change what gets built
- Org and marketplace name stay: the GitHub org is `tokenmaxxxer` and `marketplace.json`'s `name` field is `tokenmaxxxer` (the marketplace identity, tied to the `@tokenmaxxxer` install suffix). Neither changes — only the repo name and the `tokenmaxxxer/claude-plugins` path references become `tokenmaxxxer/coding-agent-rulebook`.
- Plugin install suffixes (`freelunch@tokenmaxxxer`, etc.) are unaffected — they key off the marketplace name, not the repo name.
- GitHub keeps redirecting the old path after `gh repo rename`, so existing clones/installs keep working; the reference updates are for correctness, not to avoid breakage.
- In-repo references to the old path (measured via grep): README.md (4), install.sh (1), freelunch/README.md (4). No other tracked file references it.

## What will be done
- `gh repo rename coding-agent-rulebook` (external action; renames the GitHub repo under the same org).
- Update the local git remote URL to the new path.
- README.md: title line, the `curl .../tokenmaxxxer/claude-plugins/main/install.sh` URL, the `/plugin marketplace add tokenmaxxxer/claude-plugins`, and the `"repo": "tokenmaxxxer/claude-plugins"` source — all → `coding-agent-rulebook`.
- install.sh: `GITHUB_REPO="tokenmaxxxer/claude-plugins"` → `tokenmaxxxer/coding-agent-rulebook`.
- freelunch/README.md: the two `marketplace add` lines, the `git clone` URL, and the `cd claude-plugins` path → `coding-agent-rulebook`.

## Out of scope
- `marketplace.json` `name` field and any `@tokenmaxxxer` install suffix — those are the marketplace identity, not the repo name.
- The local working-directory path (`/home/jwjung/claude-plugins`) — renaming the checkout dir is the user's local action, not a repo change.
- Any plugin's own version or directive text.

## How I will know it worked
- `grep -rI "claude-plugins" --exclude-dir=.git .` returns nothing.
- `gh repo view tokenmaxxxer/coding-agent-rulebook` resolves; the old path redirects to it.
- `install.sh` and both READMEs point every path at `tokenmaxxxer/coding-agent-rulebook`.
