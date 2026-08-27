#!/usr/bin/env bash
# test/auth.test.sh — bin/header-auth. Anonymous registration + local account
# state. Hermetic: the live POST is stubbed via HEADER_AUTH_STUB (a response-body
# file) + HEADER_AUTH_STUB_CODE, so no network is touched. HEADER_HOME is pinned
# to a sandbox so nothing reaches the real ~/.header.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

HA="$SKILL_DIR/bin/header-auth"

# A canonical success response, written to a file the stub points at.
mk_resp() {  # mk_resp <file> [claimed]
  local f="$1" claimed="${2:-false}"
  cat > "$f" <<JSON
{"account_id":"acct_test","api_key":"hdr_sk_testkey","tier":"trial","trial_ends_at":"2026-07-14T00:00:00Z","claimed":$claimed,"claim_code":"clm_xyz","claim_url":"https://joinheader.com/signup?code=clm_xyz","installation_id":"dev-test"}
JSON
}

# ── state: none on a fresh device ─────────────────────────────
sb="$(make_sandbox)"; HH="$sb/.header"
assert_eq "none" "$(env -u HEADER_API_KEY HEADER_HOME="$HH" "$HA" state)" \
  "no credentials, no .account → state none"
assert_eq "" "$(HEADER_HOME="$HH" "$HA" claim-url)" "no account → claim-url empty"

# ── register (stubbed 200) → key saved 0600, .account cached ──
mk_resp "$sb/resp.json"
out="$(env -u HEADER_API_KEY HEADER_HOME="$HH" HEADER_AUTH_STUB="$sb/resp.json" "$HA" register)"
assert_eq "registered" "$out" "register on a clean device prints 'registered'"
assert_eq "1" "$(grep -c '^HEADER_API_KEY=hdr_sk_testkey$' "$HH/credentials")" \
  "api_key from the response is saved to credentials"
assert_eq "yes" "$([ -f "$HH/.account" ] && echo yes || echo no)" ".account cache written"
assert_eq "yes" "$([ -f "$HH/installation-id" ] && echo yes || echo no)" \
  "registration mints/persists the installation-id"
case "$(ls -l "$HH/credentials")" in
  -rw-------*) assert_eq ok ok "credentials are mode 0600" ;;
  *) assert_eq "0600" "$(ls -l "$HH/credentials")" "credentials are mode 0600" ;;
esac

# ── state + claim-url after a successful register ─────────────
assert_eq "anonymous-unclaimed" "$(env -u HEADER_API_KEY HEADER_HOME="$HH" "$HA" state)" \
  "after register → state anonymous-unclaimed"
assert_eq "https://joinheader.com/signup?code=clm_xyz" \
  "$(HEADER_HOME="$HH" "$HA" claim-url)" "claim-url returns the cached URL"
assert_contains "$(HEADER_HOME="$HH" "$HA" status)" "acct_test" "status shows the account id"
assert_contains "$(HEADER_HOME="$HH" "$HA" status)" "clm_xyz"   "status surfaces the claim URL"

# ── re-register is a benign no-op (we already own the account) ─
out="$(env -u HEADER_API_KEY HEADER_HOME="$HH" HEADER_AUTH_STUB="$sb/resp.json" "$HA" register)"
assert_eq "already registered" "$out" "re-register when we own the account → no-op"

# ── claimed account → state + claim-url reflect it ────────────
sb2="$(make_sandbox)"; HH2="$sb2/.header"
mk_resp "$sb2/resp.json" true
env -u HEADER_API_KEY HEADER_HOME="$HH2" HEADER_AUTH_STUB="$sb2/resp.json" "$HA" register >/dev/null
assert_eq "anonymous-claimed" "$(env -u HEADER_API_KEY HEADER_HOME="$HH2" "$HA" state)" \
  "claimed:true in the response → state anonymous-claimed"
assert_eq "" "$(HEADER_HOME="$HH2" "$HA" claim-url)" "claimed account → claim-url empty"

# ── HTTP failure → exit 1, nothing persisted ──────────────────
sb3="$(make_sandbox)"; HH3="$sb3/.header"
mk_resp "$sb3/resp.json"
rc=0; env -u HEADER_API_KEY HEADER_HOME="$HH3" HEADER_AUTH_STUB="$sb3/resp.json" \
  HEADER_AUTH_STUB_CODE=500 "$HA" register >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "HTTP 500 → register exits 1"
assert_eq "no" "$([ -f "$HH3/credentials" ] && echo yes || echo no)" \
  "a failed register saves no key"
assert_eq "none" "$(env -u HEADER_API_KEY HEADER_HOME="$HH3" "$HA" state)" \
  "a failed register leaves state none"

# ── offline (code 000) → exit 1 ───────────────────────────────
rc=0; env -u HEADER_API_KEY HEADER_HOME="$HH3" HEADER_AUTH_STUB="$sb3/resp.json" \
  HEADER_AUTH_STUB_CODE=000 "$HA" register >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "network error (000) → register exits 1"

# ── never clobber a user-provided key ─────────────────────────
sb4="$(make_sandbox)"; HH4="$sb4/.header"; mkdir -p "$HH4"
rc=0; HEADER_API_KEY="hdr_sk_userkey" HEADER_HOME="$HH4" HEADER_AUTH_STUB="$sb3/resp.json" \
  "$HA" register >/dev/null 2>&1 || rc=$?
assert_exit 3 "$rc" "a pre-existing API key blocks register (exit 3, no clobber)"
assert_eq "no" "$([ -f "$HH4/.account" ] && echo yes || echo no)" \
  "register refusal writes no .account"
assert_eq "full" "$(HEADER_API_KEY="hdr_sk_userkey" HEADER_HOME="$HH4" "$HA" state)" \
  "a user key with no .account → state full"

# ── save-key: the "already a Header user" paste path ──────────
sb5="$(make_sandbox)"; HH5="$sb5/.header"
out="$(env -u HEADER_API_KEY HEADER_HOME="$HH5" "$HA" save-key "hdr_sk_mine")"
assert_eq "saved" "$out" "save-key stores a user-provided key"
assert_eq "1" "$(grep -c '^HEADER_API_KEY=hdr_sk_mine$' "$HH5/credentials")" \
  "save-key writes the pasted key to credentials"
case "$(ls -l "$HH5/credentials")" in
  -rw-------*) assert_eq ok ok "save-key credentials are mode 0600" ;;
  *) assert_eq "0600" "$(ls -l "$HH5/credentials")" "save-key credentials are mode 0600" ;;
esac
assert_eq "no" "$([ -f "$HH5/.account" ] && echo yes || echo no)" \
  "save-key writes no .account (a pasted key is a full account)"
assert_eq "full" "$(env -u HEADER_API_KEY HEADER_HOME="$HH5" "$HA" state)" \
  "after save-key → state full"

# save-key supersedes a stale anonymous .account
sb6="$(make_sandbox)"; HH6="$sb6/.header"
mk_resp "$sb6/resp.json"
env -u HEADER_API_KEY HEADER_HOME="$HH6" HEADER_AUTH_STUB="$sb6/resp.json" "$HA" register >/dev/null
assert_eq "anonymous-unclaimed" "$(env -u HEADER_API_KEY HEADER_HOME="$HH6" "$HA" state)" \
  "(precondition) device starts on an anonymous account"
env -u HEADER_API_KEY HEADER_HOME="$HH6" "$HA" save-key "hdr_sk_real" >/dev/null
assert_eq "full" "$(env -u HEADER_API_KEY HEADER_HOME="$HH6" "$HA" state)" \
  "save-key removes the stale anonymous .account → state full"

# save-key with no argument → exit 1
rc=0; HEADER_HOME="$HH5" "$HA" save-key >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "save-key with no key → exit 1"

# ── trial: start / already-used / no-key ─────────────────────
sb5="$(make_sandbox)"; HH5="$sb5/.header"; mkdir -p "$HH5"
printf '{"trial_active":true,"trial_ends_at":"2026-07-22T00:00:00Z","can_start_trial":false}' > "$sb5/ok.json"
out="$(HEADER_HOME="$HH5" HEADER_API_KEY=hdr_sk_x HEADER_AUTH_BILLING_STUB="$sb5/ok.json" "$HA" trial)"
assert_contains "$out" "TRIAL_ACTIVE true"                 "trial: success prints TRIAL_ACTIVE"
assert_contains "$out" "TRIAL_ENDS_AT 2026-07-22T00:00:00Z" "trial: success prints the end date"
printf '{"detail":{"error_code":"TRIAL_ALREADY_USED","message":"used"}}' > "$sb5/used.json"
rc=0; out="$(HEADER_HOME="$HH5" HEADER_API_KEY=hdr_sk_x HEADER_AUTH_BILLING_STUB="$sb5/used.json" \
  HEADER_AUTH_BILLING_CODE=409 "$HA" trial 2>/dev/null)" || rc=$?
assert_exit 3 "$rc" "trial: 409 → exit 3"
assert_contains "$out" "ERROR_CODE TRIAL_ALREADY_USED" "trial: surfaces error_code (even wrapped in detail)"
rc=0; env -u HEADER_API_KEY HEADER_HOME="$sb5/empty" "$HA" trial >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "trial: no key → exit 2 (no network)"

# ── checkout: url / no-email / no-key ────────────────────────
printf '{"url":"https://joinheader.com/checkout/abc"}' > "$sb5/co.json"
assert_eq "CHECKOUT_URL https://joinheader.com/checkout/abc" \
  "$(HEADER_HOME="$HH5" HEADER_API_KEY=hdr_sk_x HEADER_AUTH_BILLING_STUB="$sb5/co.json" "$HA" checkout --email a@b.co)" \
  "checkout: prints CHECKOUT_URL from the response"
rc=0; HEADER_HOME="$HH5" HEADER_API_KEY=hdr_sk_x "$HA" checkout >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "checkout: no --email → exit 1"
rc=0; env -u HEADER_API_KEY HEADER_HOME="$sb5/empty" "$HA" checkout --email a@b.co >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "checkout: no key → exit 2 (no network)"

# ── subscription: tier/trial state + EXPIRED detection ───────
printf '{"trial_active":true,"can_start_trial":false,"trial_ends_at":"2026-07-22T00:00:00Z","tier_flip_kind":null}' > "$sb5/act.json"
out="$(HEADER_HOME="$HH5" HEADER_API_KEY=hdr_sk_x HEADER_AUTH_BILLING_STUB="$sb5/act.json" "$HA" subscription)"
assert_contains "$out" "TRIAL_ACTIVE true"  "subscription: active trial"
assert_not_contains "$out" "EXPIRED"         "subscription: active trial is not EXPIRED"
printf '{"trial_active":false,"can_start_trial":false,"trial_ends_at":"2026-06-01T00:00:00Z","tier_flip_kind":"trial_expired"}' > "$sb5/exp.json"
out="$(HEADER_HOME="$HH5" HEADER_API_KEY=hdr_sk_x HEADER_AUTH_BILLING_STUB="$sb5/exp.json" "$HA" subscription)"
assert_contains "$out" "TIER_FLIP_KIND trial_expired" "subscription: surfaces tier_flip_kind"
assert_contains "$out" "EXPIRED yes"                   "subscription: lapsed trial → EXPIRED yes"
rc=0; env -u HEADER_API_KEY HEADER_HOME="$sb5/empty" "$HA" subscription >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "subscription: no key → exit 2 (no network)"

# ── dispatch: --help is success, unknown subcommand is an error ─
HEADER_HOME="$HH" "$HA" --help >/dev/null 2>&1; assert_exit 0 "$?" "--help exits 0"
HEADER_HOME="$HH" "$HA" zzz-not-a-subcommand >/dev/null 2>&1; assert_exit 1 "$?" \
  "unknown subcommand exits 1"

t_done
