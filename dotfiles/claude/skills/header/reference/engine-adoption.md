# Header reference — engine adoption

*Loaded on demand by the Header skill; not part of the always-loaded SKILL.md.*

## Engine-adoption card (`/header fable-5`)

A self-contained, repo-independent answer to **"should you move your coding harness to a newer model?"** Two bundled instances: **Fable 5** (`/header fable-5`, also `fable5` / `claude-fable-5`; the 2×-price tier above Opus) and **Opus 4.8** (`/header opus-4.8`, also `opus-4-8`; the same-price in-tier move). Bare `adopt` renders the newest (Fable 5). Also offered from a `MODEL-UPGRADE` audit finding — render the card matching the finding's recommended model. It does **not** fetch a briefing; it composes a grounded card from a bundled snapshot + the user's own engine, then hands off to `header-experiment mine --adopt` for the actual proof. Full rationale: `docs/engine-adoption-design.md`.

**Render it:**

1. **Read the snapshot.** It ships with the skill under `data/engine-adoption/` (relative to the skill dir — the parent of `HEADER_BIN`'s directory): `fable-5.md` or `opus-4.8.md`, matching the argument (bare `adopt` → `fable-5.md`). It carries the grounded evidence, the verdict-by-engine rubric, the effort lever, and the caveats, every claim attributed to that model's System Card.

2. **Detect the current engine (the personalization — no repo, no key needed).**
   - **Model:** the `MODEL` line from `<AUDIT> harness`, else `ANTHROPIC_MODEL`, else the `model` in `.claude/settings.json`.
   - **Effort:** `CLAUDE_CODE_EFFORT_LEVEL` → `effortLevel` in settings → the model default (`xhigh` for Fable 5 and Opus 4.7, `high` otherwise).
   - **Spend (optional):** `<AUDIT> cost` — if the current model has a `SPEND` line, frame the effort-drop saving against real money.

3. **Present the card.** Lead with the **verdict row matching the detected engine** (the snapshot's "Verdict by the engine you run today" table). Show WHY (the grounded numbers) and — non-negotiable — WATCH (the snapshot's caveats; for Fable 5 that's the 2× price, the safeguard fallback to Opus 4.8, the diligence soft spots, and the unattended-run posture). Keep it honest: **this card is a projection**; the verdict for their harness is earned on their tasks.

4. **CTA → prove it.** End on `header-experiment mine --adopt` (mines this repo's history, runs a model+effort A/B of their current engine vs the card's target — default `claude-fable-5 @high`; `--to claude-opus-4-8` from the Opus card; `--sweep` offers a 3rd effort arm). If they're **not** in a git repo, say so — the card is the answer they get without one (grounded, but a projection); the proof needs a repo.

**Repo-independence is deliberate:** the card runs anywhere (snapshot + local settings/spend); the *proof* needs a repo. The engine (model + effort) is the repo-independent slice of the harness — which is exactly what this decides. **Future models** generalize the same flow: a `<model>` snapshot under `data/engine-adoption/` + `header-experiment mine --adopt --to <model>`.


