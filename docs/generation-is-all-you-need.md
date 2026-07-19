# Generation Is All You Need
### Separating the Generation and Verification Layers in LLM Agent Systems

**Jiwon Jung · Jongkwan Lee**

*A position paper of the `tokenmaxxxer` stack. Draft, 2026-07-20.*

---

## Abstract

Most contemporary LLM agent harnesses fuse two operations inside a single turn: they **generate** a candidate artifact and then **verify** it against the task, iterating until an internal check passes. We argue this fusion is a category error. Verification is the act of closing the gap between an artifact and a *user oracle* — the (often unstated, frequently shifting) standard by which the user will judge the result. That oracle is a moving target, is routinely outside the model's pretrained distribution, and cannot be reconstructed by the model from the prompt alone. A turn that tries to verify against an oracle it cannot know spends most of its cost failing, and — when the demanded oracle contradicts pretrained priors — actively corrupts the artifact it is supposed to improve. We propose instead a strict **layer separation**: the LLM layer is a pure *generator* run at maximum autonomy and minimum ceremony; verification is relocated to the layer above, whose oracle-holder is a human supplying feedback. Removing in-turn verification collapses per-turn cost, which unlocks large-fan-out parallel generation (drastically reducing wall-clock) and makes failure cheap enough that many small failures, steered by user feedback, converge on the oracle. The feedback rounds *are* the verification procedure; because a verification-generation is itself just a generation at the lower layer, the separation is clean and recursive. We ground each step in the software-engineering oracle-problem literature and in recent empirical work on LLM self-correction, self-verification, and inference-time scaling, and we report small-scale internal experiments consistent with the thesis — while marking honestly where the argument is conditional and where our own evidence is thin.

---

## 1. Introduction

The dominant design pattern for "agentic" LLM systems in 2025–2026 is the generate–check–repair loop: the model proposes, a checker (the model itself, a critic model, a test runner, a review pass) judges, and the loop repeats until the check is satisfied or a budget is exhausted. The pattern is intuitive — it mirrors how a careful engineer works — and it is nearly universal. It is also, we contend, the wrong place to put the check.

The claim of this paper is narrow and falsifiable:

> **Verification must not live in the same layer as generation. The generating turn should verify nothing. It should generate, cheaply and in parallel, and stop.**

This is not an argument that verification is unnecessary. It is an argument about *where verification belongs*. Our position is that the check belongs to a strictly higher layer whose oracle is a human, and that collapsing it into the generating turn is what makes modern harnesses slow, expensive, and — in an underappreciated failure mode — self-contradicting.

We build the argument in five moves: the oracle is a moving target (§2); the model cannot verify against it from inside a turn (§3); therefore the layers must separate (§4); separation makes generation cheap and parallel (§5); and cheap parallel generation plus human feedback is the actual convergence mechanism (§6). We then state the conditions under which the thesis holds and fails (§7), report internal experiments (§8), and position against related work (§9).

Three figures carry the intuition: **Figure 1** (§4) contrasts the two architectures — verification fused into the turn vs. given its own layer; **Figure 2** (§6) shows distance-to-oracle vs. cost for each; **Figure 3** (§3) shows why the two operations called "verification" pull in opposite directions. Figures 2 and 3 are schematic — they illustrate the mechanism, not measured data (the measured data is §8).

---

## 2. The oracle is a moving target

Software testing has a name for the object verification aims at and the difficulty of obtaining it: the **test oracle problem**. In Barr et al.'s survey [1], the oracle problem is "the challenge of distinguishing the corresponding desired, correct behaviour from potentially incorrect behaviour" for a given input. Their central, hard-won conclusion is that when modelling, formal specification, contract-driven development, and metamorphic relations all fall short — which is the common case for anything with taste, ambiguity, or unstated intent — "the final source of test oracle information remains the human, who may be aware of informal specifications, expectations, norms and domain specific information that provide informal oracle guidance." The human is not a fallback; the human is the oracle of last resort, and for most real tasks the *only* complete one.

Two properties of this oracle are decisive for LLM agents:

- **It is user- and task-specific, and it moves.** The standard by which *this* user will judge *this* artifact is a function of their context, their unstated preferences, and information they have not written down — and it shifts as they see intermediate results ("I'll know it when I see it"). A single, general, pre-written verification logic is a fixed dartboard trying to hit a target that relocates between throws.
- **It is frequently outside the model's pretrained distribution.** An LLM is, mechanically, a device that reproduces patterns from its pretraining distribution. When the user's oracle coincides with that distribution, generation is nearly free and nearly correct (see §8, where a frontier model produces secure code with no security prompting at all). When the oracle *diverges* from the distribution — an idiosyncratic convention, a novel constraint, a house style the training corpus never saw — the model has no internal source from which to derive it.

The oracle problem is thus not an implementation detail an agent framework can engineer away. It is a structural fact: the target of verification is external, human-held, and mobile.

---

## 3. Why in-turn verification fails

If the oracle is external and mobile, can a model at least verify against its *own* best guess of it, inside the turn, and improve? The empirical answer from the reasoning and planning literature is: no, not intrinsically, and often it makes things worse.

- **Intrinsic self-correction degrades performance.** Huang et al. [2] (ICLR 2024) define *intrinsic* self-correction as a model revising its answer "based solely on its inherent capabilities, without external feedback," and show that under this setting "LLMs struggle to self-correct their responses... and at times, their performance even degrades after self-correction." Crucially, they show that the gains reported by earlier self-correction papers were an artifact of using **oracle labels** to decide when to stop correcting — i.e., those systems already had the answer. Strip the external oracle, and self-correction turns negative.
- **Self-verification collapses; external verification helps.** Stechly, Valmeekam, and Kambhampati [3] observe "significant performance collapse with self-critique and significant performance gains with sound external verification" on reasoning and planning tasks. The companion position paper [4] ("LLMs Can't Plan, But Can Help Planning in LLM-Modulo Frameworks") makes the architectural consequence explicit: pair the LLM *generator* with an **external, model-based verifier** in a separate module. Their travel-planning system improves ~6× over baseline — precisely by not asking the generator to be its own judge.

This is the empirical core of our thesis. The model cannot verify against an oracle it does not hold, and forcing it to try, inside the turn, spends the turn's budget on a process that is at best neutral and at worst corrosive. And there is a sharper, less-remarked failure: when the user *demands* an oracle that contradicts the model's pretrained priors, an in-turn verification step does not gently correct the artifact toward the demanded oracle — it drags a distribution-consistent generation toward a distribution-inconsistent standard, and the two forces leave the artifact *internally contradictory* (a handler that satisfies the demanded rule in one place and the pretrained idiom in another). The verification step manufactures the very defect it was added to catch.

The conclusion is not "make the verifier better." It is: **the generating turn is the wrong place for the check.**

<figure>
<svg viewBox="0 0 700 340" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Verification dynamics: intrinsic self-verification drifts down while external feedback converges to the oracle">
  <rect x="0" y="0" width="700" height="340" fill="#fbfbfd" stroke="#d9dce3"/>
  <text x="350" y="26" text-anchor="middle" font-family="sans-serif" font-size="15" font-weight="700" fill="#1a202c">Figure 3. What each kind of verification does across rounds</text>
  <!-- axes -->
  <line x1="70" y1="60" x2="70" y2="285" stroke="#4a5568" stroke-width="1.5"/>
  <line x1="70" y1="285" x2="650" y2="285" stroke="#4a5568" stroke-width="1.5"/>
  <text x="60" y="70" text-anchor="end" font-family="sans-serif" font-size="12" fill="#4a5568">high</text>
  <text x="60" y="283" text-anchor="end" font-family="sans-serif" font-size="12" fill="#4a5568">low</text>
  <text x="26" y="180" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#4a5568" transform="rotate(-90 26 180)">proximity to user oracle (quality)</text>
  <text x="360" y="312" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#4a5568">rounds of verification / feedback</text>
  <!-- oracle line -->
  <line x1="70" y1="66" x2="650" y2="66" stroke="#2f855a" stroke-width="1.5" stroke-dasharray="6 4"/>
  <text x="646" y="60" text-anchor="end" font-family="sans-serif" font-size="12" fill="#2f855a">user oracle</text>
  <!-- external feedback (blue), converging up -->
  <polyline fill="none" stroke="#2b6cb0" stroke-width="2.6" points="70,175 142,140 214,114 286,96 358,84 430,76 502,71 574,68 646,67"/>
  <text x="500" y="120" font-family="sans-serif" font-size="12.5" font-weight="700" fill="#2b6cb0">external feedback</text>
  <text x="500" y="136" font-family="sans-serif" font-size="11.5" fill="#2b6cb0">(human holds the oracle)</text>
  <!-- intrinsic self-verification (red), drifting down -->
  <polyline fill="none" stroke="#c0432b" stroke-width="2.6" points="70,175 142,182 214,176 286,192 358,199 430,207 502,212 574,218 646,222"/>
  <text x="300" y="245" font-family="sans-serif" font-size="12.5" font-weight="700" fill="#c0432b">intrinsic self-verification</text>
  <text x="300" y="261" font-family="sans-serif" font-size="11.5" fill="#c0432b">(model judges its own output — drifts down)</text>
  <circle cx="70" cy="175" r="3.5" fill="#1a202c"/>
  <text x="80" y="167" font-family="sans-serif" font-size="11" fill="#1a202c">same start</text>
</svg>
<em>Figure 3 (schematic, not plotted from data). The two operations both called "verification" pull in opposite directions. Asking the model to judge its own output with no external oracle drifts quality <em>down</em> over rounds (Huang et al. [2]; Stechly et al. [3]); routing the same rounds through human feedback, which carries the oracle, converges quality up. The x-axis is rounds; only the feedback curve is a contraction toward the oracle.</em>
</figure>

---

## 4. The layered-separation thesis

We state the thesis directly.

> **Generation layer.** The LLM turn is a pure generator. It receives direction, produces an artifact from its pretrained distribution, and returns it *raw* — no self-review, no re-reading of finished work, no repair loop. It has full generative autonomy within the direction it is given.
>
> **Verification layer.** Verification lives strictly above the generating turn. Its oracle-holder is the human. Its instrument is **feedback**: the human observes an artifact and supplies a delta toward their oracle. Each feedback round re-aims the next generation.
>
> **Recursion.** A "verification-generation" — a turn spun up to critique or test — is, at the lower layer, *just another generation*. So the separation is not a special case; it is uniform and recursive. Checks can exist in abundance, but they are always generations commissioned and adjudicated from above, never self-adjudicated from within.

Two clarifications guard against misreading:

1. **This is "no checks in the generating layer," not "no checks anywhere."** Checks exist; they live above and are triggered by the oracle-holder. In our own stack, the correctness tests that score a generation sit in a *benchmark harness* one layer up, never inside the worker turn that produced the artifact (§8). The slogan "no verification" is shorthand for "no verification fused into generation."
2. **Steering is not verification.** Shaping the generator's direction *before* it writes — telling it which production structure, which exemplar bar, which secure pattern to reach for — is a generation-layer act that costs only prompt tokens and never inspects output. It reduces the distance the feedback loop must later close, without ever running a check. The distinction is exact: steering moves the *prior*; verification inspects the *sample*.

<figure>
<svg viewBox="0 0 760 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Two architectures: fused generate-check-repair versus separated generation and verification layers">
  <rect x="0" y="0" width="760" height="400" fill="#fbfbfd" stroke="#d9dce3"/>
  <text x="380" y="26" text-anchor="middle" font-family="sans-serif" font-size="15" font-weight="700" fill="#1a202c">Figure 1. Verification fused into the turn (A) vs. given its own layer (B)</text>
  <!-- divider -->
  <line x1="380" y1="44" x2="380" y2="392" stroke="#e2e5ec" stroke-width="1.5"/>

  <!-- Panel A: fused -->
  <text x="40" y="66" font-family="sans-serif" font-size="13.5" font-weight="700" fill="#c0432b">A. Fused turn — generate · check · repair</text>
  <rect x="40" y="80" width="300" height="150" rx="10" fill="#fdf0ec" stroke="#c0432b" stroke-width="1.6"/>
  <text x="190" y="100" text-anchor="middle" font-family="sans-serif" font-size="11.5" fill="#9c3320">one expensive turn</text>
  <rect x="66" y="112" width="80" height="34" rx="6" fill="#fff" stroke="#c0432b"/>
  <text x="106" y="134" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#1a202c">generate</text>
  <rect x="176" y="112" width="80" height="34" rx="6" fill="#fff" stroke="#c0432b"/>
  <text x="216" y="134" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#1a202c">self-check</text>
  <rect x="256" y="170" width="70" height="34" rx="6" fill="#fff" stroke="#c0432b"/>
  <text x="291" y="192" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#1a202c">repair</text>
  <!-- loop arrows -->
  <line x1="146" y1="129" x2="174" y2="129" stroke="#c0432b" stroke-width="1.6" marker-end="url(#ah-r)"/>
  <line x1="216" y1="146" x2="270" y2="168" stroke="#c0432b" stroke-width="1.6" marker-end="url(#ah-r)"/>
  <path d="M256 187 Q120 200 106 148" fill="none" stroke="#c0432b" stroke-width="1.6" stroke-dasharray="4 3" marker-end="url(#ah-r)"/>
  <text x="190" y="222" text-anchor="middle" font-family="sans-serif" font-size="10.5" fill="#9c3320">loop until internal check passes — cost ≈ 100, serial</text>
  <!-- oracle + gap -->
  <line x1="40" y1="270" x2="340" y2="270" stroke="#2f855a" stroke-width="1.5" stroke-dasharray="6 4"/>
  <text x="336" y="264" text-anchor="end" font-family="sans-serif" font-size="11.5" fill="#2f855a">user oracle (moving, often OOD)</text>
  <line x1="190" y1="230" x2="190" y2="290" stroke="#c0432b" stroke-width="1.6" marker-end="url(#ah-r)"/>
  <rect x="150" y="292" width="220" height="34" rx="6" fill="#fdf0ec" stroke="#c0432b"/>
  <text x="260" y="308" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#9c3320">artifact stalls below the oracle</text>
  <text x="260" y="321" text-anchor="middle" font-family="sans-serif" font-size="10.5" fill="#9c3320">self-check can't reach it — may even degrade</text>
  <text x="40" y="356" font-family="sans-serif" font-size="11" fill="#4a5568">One big failure at cost 100.</text>
  <text x="40" y="374" font-family="sans-serif" font-size="11" fill="#4a5568">The turn spends its budget adjudicating an oracle it does not hold.</text>

  <!-- Panel B: separated -->
  <text x="410" y="66" font-family="sans-serif" font-size="13.5" font-weight="700" fill="#2b6cb0">B. Separated layers — generate below, verify above</text>
  <!-- verification layer -->
  <rect x="410" y="80" width="320" height="46" rx="10" fill="#eaf1f9" stroke="#2b6cb0" stroke-width="1.6"/>
  <text x="570" y="100" text-anchor="middle" font-family="sans-serif" font-size="12.5" font-weight="700" fill="#2b6cb0">VERIFICATION LAYER — human feedback</text>
  <text x="570" y="116" text-anchor="middle" font-family="sans-serif" font-size="10.5" fill="#2b6cb0">holds the oracle · picks · sends a delta</text>
  <!-- generation layer: parallel cheap workers -->
  <text x="410" y="168" font-family="sans-serif" font-size="11.5" fill="#4a5568">GENERATION LAYER — many equal cheap generators, in parallel</text>
  <g>
    <rect x="410" y="178" width="52" height="40" rx="6" fill="#fff" stroke="#2b6cb0"/>
    <rect x="472" y="178" width="52" height="40" rx="6" fill="#fff" stroke="#2b6cb0"/>
    <rect x="534" y="178" width="52" height="40" rx="6" fill="#fff" stroke="#2b6cb0"/>
    <rect x="596" y="178" width="52" height="40" rx="6" fill="#fff" stroke="#2b6cb0"/>
    <rect x="658" y="178" width="52" height="40" rx="6" fill="#fff" stroke="#2b6cb0"/>
  </g>
  <text x="436" y="202" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#1a202c">gen</text>
  <text x="498" y="202" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#1a202c">gen</text>
  <text x="560" y="202" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#1a202c">gen</text>
  <text x="622" y="202" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#1a202c">gen</text>
  <text x="684" y="202" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#1a202c">gen</text>
  <text x="570" y="234" text-anchor="middle" font-family="sans-serif" font-size="10.5" fill="#2b6cb0">raw, no self-check — cost ≈ 1 each · concurrent</text>
  <!-- candidates up -->
  <line x1="570" y1="178" x2="570" y2="128" stroke="#2b6cb0" stroke-width="1.6" marker-end="url(#ah-b)"/>
  <text x="578" y="150" font-family="sans-serif" font-size="10.5" fill="#2b6cb0">candidates ↑</text>
  <!-- feedback down -->
  <path d="M700 126 Q724 160 700 176" fill="none" stroke="#2b6cb0" stroke-width="1.6" marker-end="url(#ah-b)"/>
  <text x="712" y="152" font-family="sans-serif" font-size="10.5" fill="#2b6cb0">feedback ↓</text>
  <!-- oracle reached -->
  <line x1="410" y1="270" x2="730" y2="270" stroke="#2f855a" stroke-width="1.5" stroke-dasharray="6 4"/>
  <text x="726" y="264" text-anchor="end" font-family="sans-serif" font-size="11.5" fill="#2f855a">user oracle</text>
  <circle cx="570" cy="270" r="5" fill="#2f855a"/>
  <text x="570" y="290" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#2f855a">artifact converges onto the oracle across rounds</text>
  <text x="410" y="356" font-family="sans-serif" font-size="11" fill="#4a5568">Fifty small failures at cost 1 — same budget, but they populate</text>
  <text x="410" y="374" font-family="sans-serif" font-size="11" fill="#4a5568">the option space the human then selects and steers from.</text>

  <defs>
    <marker id="ah-r" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#c0432b"/></marker>
    <marker id="ah-b" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#2b6cb0"/></marker>
  </defs>
</svg>
<em>Figure 1. (A) The generate–check–repair turn tries to reach a human-held, moving oracle from inside a single expensive turn, and stalls below it. (B) The generating layer emits raw candidates cheaply and in parallel; the verification layer above holds the oracle (a human) and closes the gap through feedback across rounds. Same total budget; different topology.</em>
</figure>

---

## 5. The economics: cheap parallel generation

Removing in-turn verification is not merely a purity move; it changes the cost structure, and the new structure is strictly better under a realistic model of where value comes from.

**Cheap turns.** A turn with no verification prompt, no critic call, no repair iteration is a fraction of the cost and latency of a generate–check–repair turn. Nothing is spent adjudicating an oracle the turn cannot know.

**Parallel turns.** Here the pretrained-generator premise pays a second dividend. Because every agent draws on the *same* pretrained distribution, agents are largely interchangeable in capability. That interchangeability is exactly what licenses spawning many of them at once: there is no "smartest agent" to wait for, so a task's generation can be fanned across a large number of equal workers and reassembled, cutting wall-clock roughly in proportion to the fan-out (bounded by contract-freezing and assembly overhead). This matches the inference-time-scaling literature: Brown et al.'s *Large Language Monkeys* [5] shows that **coverage** — the fraction of problems solved by *any* of *k* samples — scales log-linearly with *k* over four orders of magnitude, and reports that "amplifying the cheaper DeepSeek model with five samples is more cost-effective and solves more issues than paying a premium for one sample from GPT-4o or Claude 3.5 Sonnet." Snell et al. [6] likewise find test-time compute can be spent more effectively than scaling parameters, and separate the two regimes we care about: *sequential* refinement (the repair loop we reject) vs. *parallel* sampling of independent candidates (the fan-out we adopt).

**Cheap failure.** Put cheap turns and parallel turns together and failure becomes affordable. The governing inequality is blunt:

> One failure at cost 100 is worse than fifty failures at cost 1.

A single expensive, verification-laden turn that fails — the common outcome when its internal oracle misses the user's — burns a large fixed cost for nothing. Fifty cheap generations, most of which also "fail" against the user's true oracle, cost the same in total but *do something the expensive failure cannot*: they populate the option space the human oracle-holder then selects and steers from. This is the *Monkeys* coverage result read as an operating philosophy: buy breadth with cheap samples, and let the oracle pick.

---

## 6. The convergence engine is feedback, not agent count

It is tempting to conclude that if cheap parallel generation is good, more of it is the whole answer — that enough agents will find the oracle on their own. This is false, and the reason it is false comes from the *same* premise that justified the fan-out.

**Correlated failure.** Agents are interchangeable because they share a pretrained distribution. But shared priors mean *shared blind spots*: on an oracle that lies outside the pretrained distribution, N equal agents do not explore N independent guesses — they fail in the **same direction**, N times. Parallelism therefore buys **wall-clock**, not **oracle-hitting**. It compresses the time to produce a round of candidates; it does not, on its own, move those candidates toward an out-of-distribution target. The inference-scaling literature says the same thing from the other side: repeated sampling raises *coverage*, but converting coverage into a *solution* requires a verifier to select the good sample, and Snell et al. [6] warn that "imperfect verifiers lead to diminishing returns, especially when false positives dominate." Coverage without a sound oracle is unpicked breadth.

**Feedback is the only thing that moves toward an OOD oracle.** In the layered architecture, the sound oracle is the human, and the mechanism that transmits it is feedback. Each feedback round injects information the pretrained distribution does not contain, re-aiming the next (cheap, parallel) generation. This is the same mechanism by which base models are aligned to human preference in the first place — learning from human feedback is how a distribution-general generator is bent toward a specific human standard [7, 8]. In the agent loop it operates online and per-task rather than in training, but the role is identical: **feedback is the verification procedure**, spread across rounds.

**The two levers multiply, but only one converges.** Speed (parallel generation) and accuracy (feedback) are not substitutes. Cheap fast turns make *more feedback rounds affordable* in a given wall-clock and budget; feedback makes each round *point somewhere better*. Their product is a system that reaches the user's oracle in more, faster, better-aimed iterations than a system that spends the same budget on one expensive, self-verifying, slow turn that still misses. But agent count alone, absent feedback, converges on the *centroid of the pretrained prior* — not on the user.

<figure>
<svg viewBox="0 0 700 360" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Distance to the user oracle versus cumulative cost: the fused turn plateaus above the oracle while separated cheap turns plus feedback converge onto it">
  <rect x="0" y="0" width="700" height="360" fill="#fbfbfd" stroke="#d9dce3"/>
  <text x="350" y="26" text-anchor="middle" font-family="sans-serif" font-size="15" font-weight="700" fill="#1a202c">Figure 2. Distance to the user oracle vs. cumulative cost</text>
  <!-- axes -->
  <line x1="72" y1="56" x2="72" y2="290" stroke="#4a5568" stroke-width="1.5"/>
  <line x1="72" y1="290" x2="650" y2="290" stroke="#4a5568" stroke-width="1.5"/>
  <text x="62" y="66" text-anchor="end" font-family="sans-serif" font-size="12" fill="#4a5568">far</text>
  <text x="62" y="276" text-anchor="end" font-family="sans-serif" font-size="12" fill="#4a5568">at oracle</text>
  <text x="26" y="175" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#4a5568" transform="rotate(-90 26 175)">distance to user oracle</text>
  <text x="361" y="318" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#4a5568">cumulative cost / wall-clock  →</text>
  <!-- oracle baseline -->
  <line x1="72" y1="278" x2="650" y2="278" stroke="#2f855a" stroke-width="1.5" stroke-dasharray="6 4"/>
  <text x="646" y="272" text-anchor="end" font-family="sans-serif" font-size="12" fill="#2f855a">user oracle</text>
  <!-- fused: few big steps, plateau above oracle, slight uptick -->
  <polyline fill="none" stroke="#c0432b" stroke-width="2.6" points="72,80 168,80 168,168 340,168 340,196 520,196 520,188 650,188"/>
  <circle cx="72" cy="80" r="3.5" fill="#c0432b"/>
  <circle cx="168" cy="168" r="3.5" fill="#c0432b"/>
  <circle cx="340" cy="196" r="3.5" fill="#c0432b"/>
  <circle cx="520" cy="188" r="3.5" fill="#c0432b"/>
  <text x="356" y="150" font-family="sans-serif" font-size="12.5" font-weight="700" fill="#c0432b">fused turn (self-verify + repair)</text>
  <text x="356" y="166" font-family="sans-serif" font-size="11" fill="#c0432b">few big steps · plateaus above oracle · may tick up</text>
  <!-- separated: many small steps to oracle -->
  <polyline fill="none" stroke="#2b6cb0" stroke-width="2.6" points="72,80 110,104 148,124 186,142 224,160 262,178 300,196 338,212 376,228 414,242 452,253 490,262 528,269 566,273 604,276 650,277"/>
  <text x="150" y="250" font-family="sans-serif" font-size="12.5" font-weight="700" fill="#2b6cb0">separated: cheap parallel turns + feedback</text>
  <text x="150" y="266" font-family="sans-serif" font-size="11" fill="#2b6cb0">many small steps · converges onto the oracle</text>
</svg>
<em>Figure 2 (schematic, not plotted from data). Same budget on the x-axis. The fused turn buys a few large, expensive steps and stalls above the oracle — its self-check cannot supply the out-of-distribution information the last gap needs, and can regress (Huang et al. [2]). Splitting the budget into many cheap parallel turns, each re-aimed by feedback, spends the same total but keeps closing the distance because every round injects oracle information the model lacked. Parallelism sets the step <em>rate</em>; feedback sets the step <em>direction</em> — only their product reaches the target.</em>
</figure>

---

## 7. Conditions and limits

The thesis is conditional, and honesty requires stating the conditions.

- **Convergence needs feedback to be a contraction.** "Many cheap failures + feedback → oracle" holds when each feedback round pulls the artifact *toward* the oracle — formally, when the feedback map is a contraction toward the fixed point. If the user recognizes their oracle only when they see it but cannot articulate the delta, feedback can **oscillate** rather than converge. The defense is not a self-verifying turn (which cannot help — the model still lacks the oracle); it is that cheap turns make even non-monotone, exploratory search affordable. The thesis survives with the caveat attached: it guarantees *affordable search*, not *monotone convergence*.
- **In-distribution oracles are a degenerate (easy) case.** When the user's oracle coincides with the pretrained distribution, generation is at ceiling and *neither* verification nor extra feedback buys much — steering and a single cheap turn suffice. Our own security experiment (§8) lands here: the effect of adding a security-steering directive was zero because the baseline was already secure. This is not evidence against the thesis; it is the thesis's boundary, where the interesting dynamics vanish.
- **Some oracles are stable and cheap to check — put those checks above, not inside.** "Does it compile / parse / typecheck" is a stable, machine-computable oracle. The thesis does not forbid such checks; it forbids fusing them into the generating turn. They belong in the layer above (a harness gate, a CI step), commissioned by the oracle-holder — exactly where a benchmark's test scripts sit in our own stack.
- **Safety and irreversibility are out of scope for "cheap failure."** The 50-failures-at-cost-1 calculus assumes failures are *recoverable*. Where a failed generation has irreversible external effect (a destructive action, a published artifact), the economics change and a higher-layer gate before the effect is warranted — again, above the generating turn, not inside it.

---

## 8. Internal evidence

We report small experiments run within the `tokenmaxxxer` stack. They are consistent with the thesis but are, by construction, low-powered — single corpora, mostly single runs — and we grade them as suggestive, not conclusive. Notably, the experiments themselves *enact* the architecture: worker turns generate raw with no self-verification, and every check below sits in a benchmark harness one layer up, triggered by the human operator.

- **Parallel generation without verification matches quality at lower wall-clock.** An ablation of the stack's parallel-generation plugin (18 tasks, plugin on/off, 72 headless runs, scored by hidden test scripts the agent cannot see) measured a 1.50× geometric-mean wall-clock speedup with **quality tied** (630/632 objective checks passing in both arms). Removing the verification ceremony cost nothing measurable on tasks precise enough to one-pass. *Limit: the suite's pass rates sit near ceiling in both arms, so this is evidence from in-distribution tasks (§7), not a general license.*
- **Fan-out holds at mid-project scale.** A 12-file, five-domain REST service (cross-domain validation, file persistence, bearer auth) built against one frozen ~90-line contract: 7 parallel workers vs. a single-agent control, judged by a 34-assertion end-to-end test **pre-registered before generation**. Both arms passed 34/34; the parallel arm finished in 47.8 s vs. 125.0 s (2.6×), with zero cross-worker integration defects on first boot. The check lived entirely in the harness; no worker verified anything. *Limit: single run per arm, greenfield, contract-amenable task.*
- **Sub-turn parallelism is real when the contract is frozen.** One worker per exported symbol, mechanically concatenated, vs. a whole-module control (pre-registered 60-assertion battery): 2.7× wall-clock at equal quality. The one failure class — a worker omitting an `export` keyword — was a *seam* defect, eliminated not by a review pass but by freezing each unit's signature line in the contract (a steering act, §4): zero seam defects across all subsequent signature-frozen runs.
- **A null result, reported.** Adding a security-*steering* directive (direction only, no scan) to vulnerability-prone generation tasks produced **no measurable improvement**: 8/8 secure in both arms, because a frontier generator already selects the secure pattern unprompted. We record this as the in-distribution boundary case of §7, not as a success. *Two initial "failures" were scorer false positives, corrected by inspection; the scorer is grep-based and single-run.*

The pattern across all four: the generating turn never verified, the checks lived above it, and the results were competitive or better at markedly lower cost — with the honest exception that steering buys nothing when the baseline is already at the oracle.

---

## 9. Related work and positioning

Our thesis sits against three nearby lines.

- **Self-correction / self-refinement.** Systems that ask a model to critique and revise its own output. The evidence [2, 3] is that the *intrinsic* version (no external oracle) is neutral-to-harmful; the versions that work smuggle in an external signal. We read this as evidence against in-turn verification and *for* relocating the oracle to a higher (human) layer.
- **Generator + external verifier (LLM-Modulo, verifier-guided search).** Kambhampati et al. [4] and the test-time-compute line [5, 6] both separate generation from a *sound external* verifier. We agree with the separation and differ on the verifier's identity: rather than engineering a formal or learned verifier to stand in for the oracle, we hold that for the moving, out-of-distribution oracles that dominate real work, the sound verifier is the human, and the interface is feedback across cheap iterations. Where a sound formal verifier *does* exist (compilers, type checkers, unit tests), we place it in the higher layer, consistent with their architecture.
- **The oracle problem.** Our framing is, in a sense, the oracle problem [1] transplanted from software testing to LLM agents: the same conclusion — that the ultimate oracle is human and cannot be fully automated — implies the same architecture — that the human-held oracle must not be faked inside an automated generating step.

The name of this paper is a deliberate inversion of the field's reflex to add ever more inspection machinery. Our claim is that, *at the generating layer*, the machinery to add is none: generation is all you need — provided verification is given its own layer, and a human its rightful place in it.

---

## 10. Conclusion

The generate–check–repair turn fuses two operations that belong in different layers. Verification targets a user oracle that is mobile, human-held, and often outside the model's pretrained distribution; a generating turn cannot reconstruct that oracle, and forcing it to try wastes the turn at best and corrupts the artifact at worst. Relocating verification to a higher layer whose oracle-holder is a human makes the generating turn a pure, cheap, parallelizable generator; makes failure cheap enough to prefer many small failures to one expensive one; and makes the human's feedback — not the model's self-scrutiny, and not raw agent count — the engine that converges the artifact on the oracle. The checks do not disappear; they move up, where a sound oracle actually lives. At the layer where the tokens are spent generating, the right amount of verification is zero.

*Generation is all you need — everything else is a different layer's job.*

---

## References

[1] E. T. Barr, M. Harman, P. McMinn, M. Shahbaz, S. Yoo. "The Oracle Problem in Software Testing: A Survey." *IEEE Transactions on Software Engineering*, 2015. https://ieeexplore.ieee.org/document/6963470/

[2] J. Huang, X. Chen, S. Mishra, H. S. Zheng, A. W. Yu, X. Song, D. Zhou. "Large Language Models Cannot Self-Correct Reasoning Yet." *ICLR 2024*. https://arxiv.org/abs/2310.01798

[3] K. Stechly, K. Valmeekam, S. Kambhampati. "On the Self-Verification Limitations of Large Language Models on Reasoning and Planning Tasks." 2024. https://arxiv.org/abs/2402.08115

[4] S. Kambhampati, K. Valmeekam, L. Guan, M. Verma, K. Stechly, S. Bhambri, L. Saldyt, A. Murthy. "Position: LLMs Can't Plan, But Can Help Planning in LLM-Modulo Frameworks." *ICML 2024*. https://arxiv.org/abs/2402.01817

[5] B. Brown, J. Juravsky, R. Ehrlich, R. Clark, Q. V. Le, C. Ré, A. Mirhoseini. "Large Language Monkeys: Scaling Inference Compute with Repeated Sampling." 2024. https://arxiv.org/abs/2407.21787

[6] C. Snell, J. Lee, K. Xu, A. Kumar. "Scaling LLM Test-Time Compute Optimally can be More Effective than Scaling Model Parameters." 2024. https://arxiv.org/abs/2408.03314

[7] P. Christiano, J. Leike, T. B. Brown, M. Martic, S. Legg, D. Amodei. "Deep Reinforcement Learning from Human Preferences." *NeurIPS 2017*. https://arxiv.org/abs/1706.03741

[8] L. Ouyang et al. "Training Language Models to Follow Instructions with Human Feedback." *NeurIPS 2022*. https://arxiv.org/abs/2203.02155

---

*Internal experiment data referenced in §8 lives in the `tokenmaxxxer` research clone under `experiments/` (routing-eval-v2.3, symbol-eval-v2.4, packing-eval-v2.5, midproj-eval-v2.5, nofootgun-eval-v0.1) and the plugin ablation in `docs/paper/`. This paper is a position statement; the internal results are small-n and single-run, and are cited as suggestive, not conclusive.*
