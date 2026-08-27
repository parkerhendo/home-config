# Header reference — cost

*Loaded on demand by the Header skill; not part of the always-loaded SKILL.md.*

## Cost analytics (`header-cost`) — beta

> **Beta — the "billing meter" of the optimization platform** (Phase 1 of `docs/experiments-design.md`).
> Costs token usage against a price table, breaks spend down by model. All local; nothing is sent. **Prices are defaults — confirm against current Anthropic pricing**; overridable in `~/.header/prices.tsv`.

Triggered by `/header cost` or "how much am I spending / token spend / what would routing to a cheaper model save". `<COST>` is `header-cost`, next to the preamble's `HEADER_BIN`.

**Verify prices are current *before* presenting any figures.** A stale price makes every number wrong. Before reporting cost:
1. If `HEADER_PRICES_URL` is set, run `"<COST>" refresh` to pull the served table.
2. Otherwise fetch **current** Anthropic pricing — `https://platform.claude.com/docs/en/about-claude/pricing` — and write it to `~/.header/prices.tsv` (`family input output cache_read cache_write`, one line each).

`report` prints the price source + freshness on stderr — **always surface that line with the figures**. Never quote a cost number without saying which prices it used and when they were checked.

**Billing mode — say which, every time.** The `$` figures are **API (pay-per-token) rates**. Two cases:
- **API / Console (pay-per-token):** the `$` is real spend. Savings are real dollars.
- **Claude subscription** (Pro $20 / Max $100 / $200): flat fee, **no** per-token cost. The `$` is a **shadow/API-equivalent** number; the real constraint is **usage limits**. The win isn't dollars, it's **headroom**. The **percentage** savings is identical; only the dollar interpretation changes.

If you don't know which mode the user is on, ask. Don't quote a dollar "saving" to a subscription user as if it were money off their bill.

**Where usage comes from.** The tool reads usage JSONL (`{"model","input_tokens","output_tokens","cache_read_tokens","cache_write_tokens","ts"}`, cache fields optional) and parses raw Claude Code transcripts best-effort (cache-write 5m/1h split priced correctly; legacy Opus 3.x/4.0/4.1 auto-detected and priced apart from current Opus). Zero-setup:

```bash
find ~/.claude/projects -name '*.jsonl' -exec cat {} + | "<COST>" report
find ~/.claude/projects -name '*.jsonl' -exec cat {} + | "<COST>" report --since 2026-05-01
```

**Where the spend is.** `report` ranks models by cost — surface the biggest line and name the obvious lever. The audit-led flow already does this automatically via `<AUDIT> cost` (see "`header-audit cost`"), which wraps this `report` over your transcripts and hands the top line back as a `ROUTE-CANDIDATE`; reach for `header-cost` directly for the full per-model table, `--json`, ad-hoc `cost` tuples, or `refresh`.

**No projections — name the lever, don't guess the saving.** A price re-rating of the same tokens is a guess. `"<COST>" savings` exists only to point at the experiment loop — the user can drive it locally with `header-experiment` (see the next section), and `savings` prints the four-command recipe.

Other subcommands: `"<COST>" refresh [--url U]`, `"<COST>" prices`, `"<COST>" cost <model> <in> <out> [cache_read] [cache_write_5m] [cache_write_1h]`. Add `--json` for machine output.


