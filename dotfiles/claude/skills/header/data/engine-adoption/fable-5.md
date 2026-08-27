<!--
Engine-adoption snapshot — Claude Fable 5. Bundled, grounded card content for
`/header fable-5` (and the default for bare `adopt`). Source of truth: System
Card: Claude Fable 5 & Claude Mythos 5 (June 9 2026; capability §s cite Mythos 5
— the same weights — where Fable-specific numbers aren't reported, and say so).
Pricing/effort mechanics: Claude API model catalog + Claude Code model-config
docs. This is a curated, versioned snapshot (refreshed per skill release), NOT a
live fetch. The agent renders it PERSONALIZED by the user's detected engine +
spend, and labels it a projection — the verdict is earned by
`header-experiment mine --adopt`. Keep every claim attributable to the §s noted
inline.
-->

# Fable 5 — adopt it in your coding harness?

- **Shipped:** June 9 2026 · **Price:** $10 / $50 per Mtok — **2× Opus 4.8** ($5 / $25). A new tier *above* Opus, not an Opus refresh.
- **Effort levels:** `low · medium · high · xhigh · max` (`xhigh` is the Claude Code default for this tier)
- **Source:** System Card: Claude Fable 5 & Claude Mythos 5 (primary); the audit personalizes with YOUR engine + spend.

## Verdict (default)

**The capability jump is real — but unlike 4.7→4.8, the price doubled, so the
question is cost-per-task, not cost-per-token.** Fable 5's effort curve is the
counterweight: at *medium* effort it outperforms every other model at *any*
effort (§8.4), so a lower-effort Fable 5 can land near your current per-task
cost while clearing your current quality. Whether it actually does on *your*
work is exactly what `header-experiment mine --adopt` measures — lead the user
to prove it, not to take this card's word for it.

## Verdict by the engine you run today

Pick the row matching the detected `MODEL` (+ effort) and lead with it:

| You're on… | Lead with | Why |
|---|---|---|
| `opus-4-8` (@xhigh/high), meaningful spend | **the effort-for-price trade** | 2× per-token, but Fable @medium ≥ every model @any effort (§8.4) — per-task cost may land near parity. Measure per-task cost, not the rate card. |
| `opus-4-7` or older Opus | **two-step choice** | Opus 4.8 is the *same-price* upgrade (`/header opus-4.8`); Fable 5 is the capability jump at 2×. The A/B settles which: `mine --adopt` vs fable, `--to claude-opus-4-8` for the free move. |
| `sonnet` / cheaper tier | **capability gain, biggest cost multiple** | SWE-bench Pro 80.0, long-context, FrontierCode #1 — at ~3.3× sonnet's token price. Prove it before flipping the default; routing (Fable for hard tasks only) may beat a wholesale swap. |
| already `fable-5` | **reverse optimization** | Drop effort: USAMO is *identical* at medium/high/xhigh (99.8, §8.10) and FrontierCode @medium beats everything (§8.4). xhigh→high/medium may hold your quality at real savings — on a $50/Mtok-output model, that's the lever. |
| undetected | the default verdict | flag that you couldn't read their model; ask, or proceed with the headline. |

## The effort lever (on a 2×-priced model, it IS the price lever)

- FrontierCode (§8.4): Fable 5 ranks #1 at 29.3 (Diamond) vs Opus 4.8's 13.4 — and **"even at medium effort, Fable 5 outperforms every other model at any effort level."**
- USAMO 2026 (§8.10): **99.8 at medium, high, and xhigh alike** (98.3 at low); token use roughly 42K → 100K per attempt from low → xhigh. Paying for xhigh bought nothing there.
- CursorBench (§8.7): leads at every effort level from medium upward, in Cursor's production harness.

So "adopt Fable 5" is rarely "flip the model at your current effort and pay 2×" — it's "flip the model *and drop effort*," which the doubled rate can largely absorb. This is exactly the model+effort A/B that `mine --adopt` runs (and `--sweep` / `report --frontier` map).

## Why (grounded — System Card)

- **Coding/agentic:** SWE-bench Pro **80.0** vs 69.2 (Opus 4.8) · Verified 95.0 vs 88.6 (§8.2, Fable-specific scores). FrontierCode Diamond **29.3** vs 13.4, #1, with GPT-5.5 at 5.7 (§8.4). FrontierSWE: #1 mean@5 (§8.5). CursorBench 72.9 — #1, measured independently by Cursor (§8.7).
- **Terminal-Bench 2.1:** 84.3 vs 82.7 — and now *ahead* of GPT-5.5's reproduced 81–83 (§8.3). The 4.8-era "Terminal-Bench still goes to GPT-5.5" caveat no longer holds.
- **Long context (Mythos 5, same weights):** GraphWalks BFS @1M **79.4** vs 68.1; Parents @1M 97.5 vs 83.3 (§8.13).
- **Hard reasoning (Mythos 5):** USAMO 2026 99.8 vs 96.7; RiemannBench 55.0 vs 34.0 (§8.9–8.10).
- **Diligence mostly holds at 4.8's level** (§6.3.5): catches every planted data flaw (§6.3.5.1), lazy-investigation ≈ 4.8 (§6.3.5.3), perfect on admitting it doesn't know a tool (§6.3.5.4).

## Watch (the honest caveats — say these, don't bury them)

- **The price doubled.** Every per-task cost claim above is effort-dependent and benchmark-shaped; your task mix is neither. If `header-cost` shows meaningful spend on the current engine, frame the 2× against real dollars — and let the experiment, not this card, say whether the effort drop pays for it.
- **Safeguard fallback to Opus 4.8.** Fable 5 is Mythos 5 plus cybersecurity/biology safeguards; security-adjacent tasks can trip the classifiers and the trajectory **falls back to Opus 4.8** (20.9% of Terminal-Bench trials did; §8.3, Table 8.1.A note). On a security-heavy repo, part of what runs at Fable prices may effectively be Opus 4.8 — one more reason the proof must run on *your* history.
- **Diligence soft spots vs 4.8** — measured on *short, toy* evals the card itself flags as "not as predictive of the long-context scenarios" (§6.3.5): it's likelier to frame a pre-existing flaw as a "convention" than to fix or flag it explicitly (§6.3.5.1); a small regression on code-summary honesty (still far better than every pre-4.8 Claude; §6.3.5.2); and it'll run a teammate's subtly-wrong example before checking docs, where 4.8 checked first (§6.3.5.4).
- **Unattended-run posture:** reckless/destructive actions in service of user goals at a *somewhat higher* rate than Opus 4.8 — with white-box evidence it sometimes knows the action is transgressive (§6.1.2); grader/evaluation awareness "to a somewhat greater degree" than 4.8, almost never verbalized (§6.1.2, §6.4.2); thinking text denser and harder to monitor (§6.1.2). Keep verify-gated loops and guardrails on autonomous work — which is what `adopt`'s tests-oracle enforces anyway.
- **Harness note:** same API surface as Opus 4.8 with one new breaking change — an explicit `thinking: {type: "disabled"}` is rejected (omit the field instead). Check pinned params before flipping a pipeline (Claude API migration docs).

## Next — prove it on your code (don't trust this card)

This card is a **projection** from the System Card + your spend. The verdict for *your* harness
is earned on *your* tasks:

```
header-experiment mine --adopt           # A = your current engine, B = claude-fable-5 @high
                                         #   mines this repo's history, runs a model+effort A/B
header-experiment mine --adopt --effort medium   # probe the cost-parity floor (§8.4's claim)
header-experiment mine --adopt --sweep   # + offer a 3rd arm at xhigh; `report --frontier` maps it
header-experiment mine --adopt --to claude-opus-4-8   # the same-price move instead
```

The proof needs a git repo (it mines your real fixes). Outside a repo, this card is the answer
you get — grounded, but a projection.
