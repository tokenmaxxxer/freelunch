# scout

Know the field before you build. The failure this targets: AI builds a product
in a category it never looked at — so the result competes with nothing, misses
what every customer in the category assumes, and aims at no quality bar. scout
injects a bounded reconnaissance protocol that runs once, before generation,
and feeds its result straight into the build direction.

**scout is steering, not verification.** It never compares the finished build
against competitors, and it is not a research-report generator. One
`UserPromptSubmit` directive; no gates, no sniffers. `SCOUT_OFF=1` disables it.

## The protocol

Three moves, at most two judgment gates, then build:

1. **Identify best-in-class** — one search round for who sets the quality bar
   (2-3 exemplars). Judge: actually top-tier? same segment? Swap mismatches.
2. **Extract the bar** — one round on the chosen exemplars: category must-bes,
   the 2-3 performance axes they compete on, one pattern to adopt and one to
   deliberately skip, and customer praise/complaints where reachable.
   Judge (stop rule): would another source change a build decision? If no,
   stop — digging further is deep research, out of scope.
3. **Scout brief** — ≤10 lines injected into the build plan and worker
   contracts. No battlecards, no SWOT, no matrix.

Scouting is not a one-shot: whenever a new product-facing decision surfaces
mid-build that the brief doesn't cover (an added flow, a changed scope), one
micro-round re-aims that decision and extends the brief. The trigger is always
a new decision appearing — never a timer, and never finished output; re-scout
steers what is about to be built, it does not re-examine what was built.

## Methodology lineage

The protocol compresses three established methods into a generation-time rule:

- **Competitive benchmarking** (Robert Camp, Xerox, 1989): benchmark against
  the *best-in-class*, not the average competitor, and convert the observed
  gap into targets. scout's step 1-2 is Camp's planning/analysis pair with the
  target-setting folded into the build direction.
- **Kano model** (Noriaki Kano, 1984): customer expectations are tiered —
  must-be (assumed; absence reads as broken), performance (the competitive
  axis), attractive (delighters, which drift into must-bes as categories
  mature). scout extracts the category's current must-be set as the floor and
  picks performance axes as the direction.
- **Theoretical sampling and saturation** (grounded-theory lineage, Glaser &
  Strauss): the next lookup is chosen by judgment on what was just learned,
  and collection stops when new sources stop changing decisions. This is what
  makes scout directional — judgment-interleaved, finite — rather than a
  deep-research fan-out.

## Benchmark

12-run A/B (2 product tasks × base/scout × 3 reps, mechanical must-be
checklists): scout raised category must-be coverage from 6/7 to 7/7 on every
landing-page run and from a 4.7/6 average to 5.7/6 on READMEs — and the gain
landed exactly where Kano predicts: the must-be the baseline systematically
omits (social proof on landings, badges on READMEs, in all six base runs) is
what the best-in-class frame restores. Exemplars were named in 5/6 scout
replies vs 0/6 base. Token cost was neutral on the landing task and ~2x on the
small README task. Notable: zero web searches occurred — the directive worked
by invoking trained knowledge of the field, which also means fast-moving
categories may still need live search, untested here.

Honest bounds: the lineage is real, but this compression of it has not been
A/B-benched beyond the 12-run result above. What the three methods contribute is vocabulary and stopping
discipline, not a guarantee that a two-round scout finds the true bar.

## Differentiation

Existing competitor-analysis skills (battlecard/SWOT/TAM generators, repo
teardown auditors) produce *reports for humans* or verify tech stacks. scout's
output is consumed by the same session that builds: the expectation floor and
chosen axes become part of the contract that blueprint structures, no-mock
grounds, and freelunch dispatches.

## Position in the stack

| plugin | steers |
|---|---|
| scout | what the field expects (bar + axes) |
| blueprint | what structure fits |
| no-mock | how real it must be |
| freelunch | how fast it gets built |
| terse | how tersely we talk about it |

All before generation; verification nowhere.
