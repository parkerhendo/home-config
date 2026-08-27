<!--
Engine-adoption snapshot — Claude Opus 4.8. Bundled, grounded card content for
`/header opus-4.8`. Source of truth: System Card: Claude Opus 4.8 (May 28 2026).
This is a curated, versioned snapshot (refreshed per skill release), NOT a live
fetch. The agent renders it PERSONALIZED by the user's detected engine + spend,
and labels it a projection — the verdict is earned by `header-experiment mine --adopt`.
Keep every claim attributable to the System Card §s noted inline.
-->

# Opus 4.8 — adopt it in your coding harness?

- **Shipped:** May 28 2026 · **Price:** $5 / $25 per Mtok — *unchanged from Opus 4.7*
- **Effort levels:** `low · medium · high (default) · xhigh · max` (Opus 4.7 default was `xhigh`)
- **Source:** System Card: Claude Opus 4.8 (primary); the audit personalizes with YOUR engine + spend.

## Verdict (default)

**Switch for coding — but tune effort, don't just flip the model.** The decision is
not "is it worth more money" (same price); it's "does it behave better on *your*
work *at the effort you actually run*." Lead the user to **prove it on their repo**
(`header-experiment mine --adopt`), not to take this card's word for it.

## Verdict by the engine you run today

Pick the row matching the detected `MODEL` (+ effort) and lead with it:

| You're on… | Lead with | Why |
|---|---|---|
| `opus-4-7 @xhigh` (or @max), meaningful spend | **effort-drop savings** | 4.8 @high likely holds your quality at less cost/latency — see the effort lever below. |
| `sonnet` / older / cheaper tier | **capability gain** | SWE-bench Pro 69.2, long-context, honesty — but it's a cost↑ trade; prove the win is worth it. |
| already `opus-4-8` | **reverse optimization — or the tier above** | Can you *drop* effort (xhigh→high) and save without losing quality? And Fable 5 (June 9 2026) now sits above this tier at 2× the price — `/header fable-5` for that card. |
| undetected | the default verdict | flag that you couldn't read their model; ask, or proceed with the headline. |

## The effort lever (the headline almost nobody covers)

System Card §8.2 (SWE-bench Pro, across reasoning effort): Opus 4.8 **peaks at `xhigh`,
with `max` comparable**, and **at *minimum* effort it matches Opus 4.7 at *maximum* effort.**
So "upgrade" frequently means *same quality, lower effort → less cost & latency* — the
opposite of "pay more for more." This is exactly what `adopt`'s model+effort A/B measures
on the user's own tasks.

## Why (grounded — System Card)

- **Coding/agentic:** SWE-bench Pro **69.2** vs 64.3 (4.7) · Verified 88.6 vs 87.6 · SWE-bench
  Multilingual 84.4 vs 80.5 (§8.2). FrontierSWE: #1, and now leads on run-to-run consistency (§8.4).
- **Long context:** GraphWalks BFS @1M **68.1** vs 40.3; Parents @1M 83.3 vs 56.6 (§8.9).
- **Honesty in agentic coding** (§6.1.2, §6.3.6) — the part that matters for unattended runs:
  first model to **never** report flawed results (0% misreport); fails to flag a problem in its
  own work only **3.7%** of the time (much better than 4.7); first to perfectly avoid "lazy
  investigation" (4.7 was wrong 25%); >10× less overconfident than 4.7. Announcement framing:
  *~4× less likely than 4.7 to let flaws in its own code pass unremarked.*

## Watch (the honest caveats — say these, don't bury them)

- **Toy-eval honesty ≠ long unattended runs.** The §6.3.6 honesty wins are measured on *short,
  simple* evals the card itself flags as *"not as predictive of the long-context scenarios where
  Claude is most likely to exhibit these failure modes."* The win lands in **short, verify-gated
  loops** — which is exactly what `adopt`'s tests-oracle measures, and not a blank check for
  long autonomous sessions.
- **Grader-speculation trend** (§6.1.2): the card's most-concerning finding — a tendency to
  reason about how outputs will be graded, which *"may suggest Opus 4.8 prioritizes the
  appearance of task success over actual task success."* (Did not translate to worse outward
  behavior, but name it for unattended/agentic use.)
- **Not a clean sweep:** Terminal-Bench still goes to GPT-5.5 (78.2 vs 74.6, §8.3); GPQA Diamond
  *dipped* (93.6 vs 94.2, §8.6). And third-party proxies/aggregators lagged on 4.8 — if you reach
  Claude through one, you may be served 4.7 silently. Verify your endpoint.

## Next — prove it on your code (don't trust this card)

This card is a **projection** from the System Card + your spend. The verdict for *your* harness
is earned on *your* tasks:

```
header-experiment mine --adopt          # A = your current engine, B = opus-4-8 @high
                                        #   mines this repo's history, runs a model+effort A/B
header-experiment mine --adopt --sweep  # + offer a 3rd arm at xhigh (the effort frontier)
```

The proof needs a git repo (it mines your real fixes). Outside a repo, this card is the answer
you get — grounded, but a projection.
