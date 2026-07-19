#!/usr/bin/env bash
# UserPromptSubmit hook: injects the pre-build reconnaissance directive.
#
# Methodology lineage (v0.1.0, 2026-07-19): the protocol is a compression of
# three established research methods into a generation-time steering rule —
#  - Competitive benchmarking (Camp 1989, Xerox): compare against BEST-in-class,
#    convert the observed gap into build targets. Not "who else exists" but
#    "who sets the bar".
#  - Kano model (Kano 1984): customer expectations come in tiers — must-be
#    (assumed; absence ruins the product), performance (the competitive axis),
#    attractive/delighters (which drift into must-bes over time). The baseline
#    to extract is the category's current must-be set.
#  - Theoretical sampling + saturation (grounded-theory lineage): each next
#    lookup is chosen by judgment on what was just learned, and collection
#    stops when new sources stop changing decisions. This is what makes scout
#    directional instead of deep-research fan-out.
# Kill switch: export SCOUT_OFF=1

if [ -n "$SCOUT_OFF" ]; then
  exit 0
fi

cat <<'EOF'
<scout-directive priority="high">
Before building anything that competes for a user's choice — an app, site, service, content product, or tool in a category where others already ship — scout the field first. You cannot hit a quality bar you have never looked at. This directive steers direction BEFORE generation; it adds no checks after.

WHEN IT APPLIES: the deliverable is product-shaped and a category exists. Skip scouting when the work is an internal utility, a fully-specified implementation (the spec already encodes the bar), a pure bugfix, or the user says skip. When in doubt, one identification round costs little — do it.

THE PROTOCOL (bounded, judgment-gated — at most two judge points, then build):

1. IDENTIFY BEST-IN-CLASS (benchmarking rule: the bar is set by the best, not the average). One search round: who has the top quality and the customers in this category? Pick 2-3 exemplars.
   JUDGE POINT 1: are these actually top-tier, and do they serve the same segment as this deliverable? Swap out mismatches now; a wrong reference steers the whole build wrong.

2. EXTRACT THE BAR, one round on the chosen exemplars:
   - Must-bes (Kano): what do ALL of them do that customers therefore assume? Absence of these reads as broken, not minimal.
   - Performance axes: the 2-3 dimensions they visibly compete on — pick where this deliverable will stand.
   - One pattern worth adopting and one worth deliberately skipping, with reasons tied to this deliverable's intent.
   - Customer expectations, if reachable in the same round (reviews, complaints): what do users praise and punish? Complaints reveal must-bes; praise reveals performance axes.
   JUDGE POINT 2 (saturation rule): would another source change any build decision? If no — and after one round on true top-tier exemplars it usually is no — STOP. Digging past saturation is deep research, not scouting, and is out of scope.

3. SCOUT BRIEF, then build immediately: compress into at most 10 lines — category must-bes, chosen performance axes, adopt/skip patterns, one line on segment fit. The brief feeds the build direction and any worker contracts directly. It is a steering input, not a report deliverable: no battlecards, no SWOT, no competitor matrix.

RE-SCOUT TRIGGER (scouting is not a one-shot): the brief covers the direction decisions known at the start. Whenever a NEW product-facing decision surfaces mid-build that the brief does not cover — an added flow or screen, a changed scope, a sub-deliverable nobody anticipated — run ONE micro-round on exactly that decision (how do the chosen exemplars handle it? one judge point), extend the brief by a line or two, and continue building. The trigger is a new DECISION appearing, never a timer and never finished output: re-scouting re-aims what is about to be built; it does not re-examine what was built. A decision already made and built stays made unless the user reopens it.

NEVER:
- Post-build comparison against the exemplars — scout steers before generation; it is not a review pass.
- Cloning the exemplar: the reference sets the BAR, the user's intent sets the DIRECTION. Copy the expectation level, not the product.
- Unbounded or parallel fan-out research: two judge points, then build. If the user wants an actual research report, that is a different task — say so.
- Fabricating exemplars or expectations when search is unavailable: state that scouting was skipped and why, then build on stated assumptions.

SCOPE: direction only. Composes with orchestration (freelunch): scouting runs in the main session — before decomposition, and again per re-scout trigger between build steps; the current scout brief travels to workers inside their task specs. Workers never scout mid-task. It never adds verification passes.
</scout-directive>
EOF
exit 0
