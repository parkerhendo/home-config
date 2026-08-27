#!/usr/bin/env bash
# test/cost.test.sh — unit tests for bin/header-cost (the realized-savings meter).
# HEADER_HOME is pinned to a sandbox so the override/cache files never touch the
# real ~/.header. Prices below are the verified current defaults (Opus 4.5+ = 5/25,
# Sonnet 4.x = 3/15, Haiku 4.5 = 1/5; cache read 0.1x, 5m write 1.25x).
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

HC="$SKILL_DIR/bin/header-cost"
sb="$(make_sandbox)"
COST() { HEADER_HOME="$sb" "$HC" "$@"; }

# ── cost primitive: exact arithmetic (USD per 1M tokens) ──────
assert_eq "30.000000" "$(COST cost claude-opus-4-7 1000000 1000000)" \
  "opus 1M in + 1M out = 5 + 25 = 30"
assert_eq "0.500000"  "$(COST cost opus 0 0 1000000 0)" \
  "opus 1M cache_read = 0.50"
assert_eq "6.250000"  "$(COST cost opus 0 0 0 1000000)" \
  "opus 1M cache_write 5m = 6.25"
assert_eq "10.000000" "$(COST cost opus 0 0 0 0 1000000)" \
  "opus 1M cache_write 1h = 10.00 (priced separately from 5m)"
assert_eq "13.500000" "$(COST cost claude-sonnet-4-6 2000000 500000)" \
  "sonnet 2M in + 0.5M out = 6 + 7.5 = 13.50"
assert_eq "6.000000"  "$(COST cost claude-haiku-4-5 1000000 1000000)" \
  "haiku 1M in + 1M out = 1 + 5 = 6"

# ── family matching is robust to version/name churn ───────────
assert_eq "30.000000" "$(COST cost claude-opus-4-7-20260416 1000000 1000000)" \
  "versioned id 'claude-opus-4-7-20260416' resolves to the opus family"
assert_eq "$(COST cost claude-opus-4-7 1000000 1000000)" "$(COST cost OPUS 1000000 1000000)" \
  "family match is case-insensitive"

# ── version-aware Opus: current (4.5+) = 5/25, legacy (3.x/4.0/4.1) = 15/75 ─
assert_eq "30.000000" "$(COST cost claude-opus-4-7 1000000 1000000)" \
  "Opus 4.7 = current (30 for 1M in/out)"
assert_eq "90.000000" "$(COST cost claude-opus-4-1-20250805 1000000 1000000)" \
  "Opus 4.1 = legacy (90)"
assert_eq "90.000000" "$(COST cost claude-opus-4-20250514 1000000 1000000)" \
  "Opus 4.0 (bare opus-4 + date) = legacy (90)"
assert_eq "90.000000" "$(COST cost claude-3-opus-20240229 1000000 1000000)" \
  "Opus 3 = legacy (90)"
assert_eq "30.000000" "$(COST cost claude-opus-4-5 1000000 1000000)" \
  "Opus 4.5 = current (not tripped by the legacy regex)"

# ── unknown model → exit 2, prints 0, warns on stderr ─────────
out="$(COST cost gpt-4o 1000 1000 2>/dev/null)"; rc=$?
assert_exit 2 "$rc" "unknown model → exit 2"
assert_eq "0.000000" "$out" "unknown model prints 0 cost"
assert_contains "$(COST cost gpt-4o 1000 1000 2>&1 >/dev/null)" "unknown model" \
  "unknown model warns on stderr"

# ── price overrides (family + exact id; comments/blanks ignored) ─
printf '# negotiated\nopus 10 50 1.00 12.50\n\nclaude-sonnet-4-6 2 8 0.20 2.50\n' > "$sb/prices.tsv"
assert_eq "60.000000" "$(COST cost opus 1000000 1000000)" \
  "family override: opus now 10 + 50 = 60"
assert_eq "10.000000" "$(COST cost claude-sonnet-4-6 1000000 1000000)" \
  "exact-id override: claude-sonnet-4-6 now 2 + 8 = 10"
assert_eq "18.000000" "$(COST cost sonnet 1000000 1000000)" \
  "exact-id override does NOT bleed into the bare family (sonnet stays 3 + 15 = 18)"
assert_contains "$(COST prices)" "overrides loaded from" \
  "prices notes when an override file is present"
rm -f "$sb/prices.tsv"

# ── prices: defaults present with verified values ─────────────
pr="$(COST prices)"
assert_contains "$pr" "opus"   "prices lists opus"
assert_contains "$pr" "5.00"   "prices shows the corrected opus input (5.00)"
assert_contains "$pr" "sonnet" "prices lists sonnet"
assert_contains "$pr" "haiku"  "prices lists haiku"

# ── report: aggregate by model, total, skip non-usage, sort desc ─
report_in='{"model":"claude-opus-4-7","input_tokens":1000000,"output_tokens":1000000,"ts":"2026-05-20T00:00:00Z"}
{"model":"claude-opus-4-7","input_tokens":0,"output_tokens":0,"cache_read_tokens":1000000,"ts":"2026-05-21T00:00:00Z"}
{"model":"claude-sonnet-4-6","input_tokens":2000000,"output_tokens":500000,"ts":"2026-05-21T00:00:00Z"}
{"type":"user","content":"no usage on this line"}'
rep="$(printf '%s\n' "$report_in" | COST report 2>/dev/null)"
assert_contains "$rep" "3 call(s)" "report counts only usage records (skips the user line)"
assert_contains "$rep" "30.50" "opus subtotal = 30 + 0.50 = 30.50"
assert_contains "$rep" "13.50" "sonnet subtotal = 13.50"
assert_contains "$rep" "44.00" "grand total = 44.00"
first_model="$(printf '%s\n' "$report_in" | COST report 2>/dev/null | awk '/^[[:space:]]+claude-/{print $1; exit}')"
assert_eq "claude-opus-4-7" "$first_model" "report sorts by cost desc (opus row first)"

# ── report --since filters by timestamp ───────────────────────
since_out="$(printf '%s\n' "$report_in" | COST report --since 2026-05-21 2>/dev/null)"
assert_contains "$since_out" "2 call(s)" "since drops the 2026-05-20 record"
assert_contains "$since_out" "since 2026-05-21" "report echoes the since cutoff"

# ── report parses raw Claude Code transcript lines (best-effort) ─
raw='{"type":"assistant","message":{"model":"claude-opus-4-7","usage":{"input_tokens":1000000,"output_tokens":0,"cache_creation_input_tokens":1000000,"cache_read_input_tokens":1000000}},"timestamp":"2026-05-22T00:00:00Z"}
{"type":"user","message":{"role":"user","content":"hi"}}'
raw_out="$(printf '%s\n' "$raw" | COST report 2>/dev/null)"
assert_contains "$raw_out" "1 call(s)" "raw transcript: one assistant usage line, user line skipped"
assert_contains "$raw_out" "11.75" "raw transcript (flat cache_creation → 5m fallback) = 5 + 6.25 + 0.50 = 11.75"

# ── cache 5m/1h split is priced separately (the real fix) ─────
split_in='{"type":"assistant","message":{"model":"claude-opus-4-7","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":2000000,"cache_creation":{"ephemeral_5m_input_tokens":1000000,"ephemeral_1h_input_tokens":1000000},"cache_read_input_tokens":0}}}'
split_out="$(printf '%s\n' "$split_in" | COST report 2>/dev/null)"
assert_contains "$split_out" "16.25" "5m(1M=6.25) + 1h(1M=10.00) priced separately = 16.25, not flat-2M-at-5m (12.50)"

# ── report --json (stdout is pure JSON; provenance is on stderr) ─
j="$(printf '%s\n' '{"model":"opus","input_tokens":1000000,"output_tokens":0}' | COST report --json 2>/dev/null)"
assert_contains "$j" '"total_usd":5.000000' "report --json total (opus 1M in = 5)"
assert_contains "$j" '"model":"opus"' "report --json per-model"

# ── report --input FILE ───────────────────────────────────────
printf '%s\n' '{"model":"opus","input_tokens":1000000,"output_tokens":0}' > "$sb/usage.jsonl"
assert_contains "$(COST report --input "$sb/usage.jsonl" 2>/dev/null)" "5.00" "report reads --input file"

# ── price provenance is printed on stderr for every calculation ─
prov="$(printf '%s\n' '{"model":"opus","input_tokens":1,"output_tokens":1}' | COST report 2>&1 >/dev/null)"
assert_contains "$prov" "Prices: bundled defaults as of" "report states it used bundled defaults (stderr)"
assert_contains "$prov" "verify online" "provenance nudges to verify online before relying on figures"

# ── cost basis: figures are API rates; subscription users differ ──
basis="$(printf '%s\n' '{"model":"opus","input_tokens":1,"output_tokens":1}' | COST report 2>&1 >/dev/null)"
assert_contains "$basis" "API (pay-per-token) rates" "report states the API-rate basis (stderr)"
assert_contains "$basis" "subscription" "report flags that subscription users don't pay API costs"
hdr="$(printf '%s\n' '{"model":"opus","input_tokens":1,"output_tokens":1}' | COST report 2>/dev/null)"
assert_contains "$hdr" "USD at API rates" "report header is labelled API rates"
assert_contains "$(printf '%s\n' '{"model":"opus","input_tokens":1,"output_tokens":1}' | COST report --json 2>/dev/null)" \
  '"basis":"api_rates"' "report --json carries the basis field"

# ── savings: NO projection — only the experiment-loop pointer ─
# Projections without measurement are guesses; the tool must never emit one.
sav="$(printf '%s\n' '{"model":"opus","input_tokens":1000000,"output_tokens":1000000}' | COST savings --from opus --to sonnet 2>&1)"
assert_contains     "$sav" "header-experiment"      "savings points at header-experiment for a real A/B"
assert_contains     "$sav" "measured spend only"    "savings restates that header-cost reports measured only"
assert_not_contains "$sav" "%"          "savings prints no percentage"
assert_not_contains "$sav" "Projection" "savings makes no projection claim"
assert_not_contains "$sav" "savings:"   "savings prints no savings figure"
savrc=0; printf '%s\n' '{"model":"opus","input_tokens":1,"output_tokens":1}' | COST savings >/dev/null 2>&1 || savrc=$?
assert_exit 0 "$savrc" "savings exits 0 (it's a pointer, not an error)"

# ── refresh: pulls a served table, caches it, validates payload ─
sbR="$(make_sandbox)"
REF() { HEADER_HOME="$sbR" "$HC" "$@"; }
REF refresh >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "refresh with no URL → exit 1 (graceful)"
REF refresh --url "file:///definitely/not/here.tsv" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "refresh of an unreachable URL → exit 1, prices untouched"
assert_eq "no" "$([ -f "$sbR/prices-cache.tsv" ] && echo yes || echo no)" \
  "a failed refresh writes no cache (can't poison the meter)"
# a served TSV via file:// (curl supports it) — caches and takes effect
printf 'opus 4 20 0.40 5.00\nsonnet 3 15 0.30 3.75\nhaiku 1 5 0.10 1.25\n' > "$sbR/served.tsv"
REF refresh --url "file://$sbR/served.tsv" >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "refresh of a valid served table → exit 0"
assert_eq "24.000000" "$(REF cost opus 1000000 1000000)" \
  "refreshed cache takes effect: opus now 4 + 20 = 24"
assert_contains "$(printf '%s\n' '{"model":"opus","input_tokens":1,"output_tokens":1}' | REF report 2>&1 >/dev/null)" \
  "refreshed" "provenance flips to 'refreshed ...' once a cache exists"
# refusing junk: an HTML 404 page must not become the price table
printf '<html><body>404 Not Found</body></html>\n' > "$sbR/junk.html"
REF refresh --url "file://$sbR/junk.html" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "refresh rejects a non-price-table payload (validation)"
assert_eq "24.000000" "$(REF cost opus 1000000 1000000)" \
  "after a rejected refresh the previous cache still stands (24)"
# user override still beats the refreshed cache
printf 'opus 9 45 0.90 11.25\n' > "$sbR/prices.tsv"
assert_eq "54.000000" "$(REF cost opus 1000000 1000000)" \
  "override beats cache beats defaults: opus now 9 + 45 = 54"

# ── bad / missing subcommand → exit 1 ─────────────────────────
COST bogus >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "unknown subcommand → exit 1"
COST >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "no subcommand → exit 1"

t_done
