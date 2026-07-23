---
status: landed
files:
  - warrant/hooks/directive.sh
  - dispatch/hooks/directive.sh
---

## Request (intent)

User: warrant/dispatch plugins currently persist the user's raw input verbatim into docs (proposal body "the request quoted verbatim") and into git issues ("statement of intent"). User is fine leaving actionable instructions but does not want the original text preserved verbatim. Chosen direction: 완화 — keep intent, drop verbatim.

## Constraints

- 완화, not removal: the record must still let a memoryless reader reconstruct WHAT was asked — so capture the request's intent, not delete it.
- warrant: replace "the request quoted verbatim" with "the request's intent in one or two paraphrased sentences; quote only a short phrase when exact wording changes what gets built."
- dispatch: the issue records the paraphrased intent, not a raw paste of the user's message.
- Add a sensitive-info guard line to both: strip credentials, secrets, tokens, personal data, and internal URLs before writing the record.
- Edit only the directive/hook source text; do not change unrelated plugin logic.

## What will be done

Reword the verbatim-capture instruction in `warrant/hooks/directive.sh:37` and the dispatch statement-of-intent instruction in `dispatch/hooks/directive.sh:27` per the constraints, and add the scrub guard sentence to each.

## Out of scope

- Existing proposal/issue files already written verbatim (leave them; migration is a separate human call).
- Other plugins (doctrine, freelunch, terse, no-footgun, etc.).
- Any behavior beyond the record-capture wording.

## How we'll know it worked

Grep for "quoted verbatim" and "statement of intent" in the plugin sources returns the reworded intent-based phrasing plus a scrub line; no remaining instruction to store the user's message byte-for-byte.

## What did not work

First wording made the scrub and the quote carve-out unordered siblings — a secret that was the load-bearing exact wording was licensed to be quoted verbatim, defeating the scrub; reordered so the scrub runs first and the carve-out is limited to non-sensitive text.
