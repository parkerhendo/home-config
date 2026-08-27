#!/usr/bin/env bash
# test/repo.test.sh — bin/header-repo. Binding round-trips and latest-wins use the
# HEADER_REPO_KEY override to stay hermetic; a few cases drive real `git` to verify
# remote normalization and the path fallback.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

RP="$SKILL_DIR/bin/header-repo"
HC="$SKILL_DIR/bin/header-config"

# ── bind → get round-trip ─────────────────────────────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" bind 11111111-aaaa "Proj A"
assert_eq "11111111-aaaa" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" get)" \
  "bind then get returns the bound topic"
assert_eq "" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="other-proj" "$RP" get)" \
  "a different repo key has no binding"

# ── latest line wins ──────────────────────────────────────────
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" bind 22222222-bbbb "Proj A v2"
assert_eq "22222222-bbbb" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" get)" \
  "re-bind: latest line wins"

# ── clear → forgotten (tombstone) ─────────────────────────────
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" clear
assert_eq "" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" get)" \
  "clear: get returns nothing after tombstone"

# ── list shows live bindings, hides tombstoned ────────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="live" "$RP" bind aaaa-live "Live"
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="gone" "$RP" bind bbbb-gone "Gone"
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="gone" "$RP" clear
listing="$(HEADER_HOME="$sb/.header" "$RP" list)"
assert_contains "$listing" "aaaa-live" "list includes a live binding"
assert_not_contains "$listing" "bbbb-gone" "list omits a tombstoned binding"

# ── repo_memory off → bind is a no-op, get is empty ───────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" "$HC" set repo_memory false
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" bind 33333333-cccc "Nope"
assert_eq "no" "$([ -s "$sb/.header/repos.jsonl" ] && echo yes || echo no)" \
  "repo_memory off → bind writes nothing"
assert_eq "" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" get)" \
  "repo_memory off → get is empty"

# ── seen marker round-trip (per repo) ─────────────────────────
sb="$(make_sandbox)"
assert_eq "" "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" seen)" \
  "seen is empty before anything is recorded"
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" seen "2026-05-21T00:00:00Z"
assert_eq "2026-05-21T00:00:00Z" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" seen)" \
  "seen round-trips the stored value"
assert_eq "" "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-b" "$RP" seen)" \
  "seen is per-repo — a different key sees nothing"

# ── per-repo onboarding flags (topic-offered, etc.) ───────────
sb="$(make_sandbox)"
assert_eq "no" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" flag topic-offered)" \
  "flag is 'no' before it is set"
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" flag topic-offered set
assert_eq "yes" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" flag topic-offered)" \
  "flag is 'yes' after it is set"
assert_eq "no" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-b" "$RP" flag topic-offered)" \
  "flag is per-repo — a different key is still 'no' (every repo gets its own offer)"
assert_eq "no" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" flag schedule-offered)" \
  "flags are independent by name — schedule-offered unaffected by topic-offered"

# ── per-repo enrich-mode value (custom|generic) ───────────────
sb="$(make_sandbox)"
assert_eq "" "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" enrich-mode)" \
  "enrich-mode is empty before anything is recorded"
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" enrich-mode custom
assert_eq "custom" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" enrich-mode)" \
  "enrich-mode round-trips the stored value"
assert_eq "" "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-b" "$RP" enrich-mode)" \
  "enrich-mode is per-repo — a different key sees nothing"
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" enrich-mode generic
assert_eq "generic" \
  "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" enrich-mode)" \
  "enrich-mode can be overwritten (custom → generic)"
rc=0; HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" enrich-mode bogus >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "enrich-mode rejects a value outside custom|generic"
# repo_memory off → enrich-mode set is a no-op
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" "$HC" set repo_memory false
HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" enrich-mode custom
assert_eq "" "$(HEADER_HOME="$sb/.header" HEADER_REPO_KEY="proj-a" "$RP" enrich-mode)" \
  "repo_memory off → enrich-mode set persists nothing"

# ── git remote normalization (real git) ───────────────────────
sb="$(make_sandbox)"; repo="$sb/work"; mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" remote add origin "git@github.com:me/proj.git"
assert_eq "github.com/me/proj" \
  "$(cd "$repo" && HEADER_HOME="$sb/.header" "$RP" key)" \
  "scp-form git remote normalizes to host/path"
git -C "$repo" remote set-url origin "https://user:tok@github.com/me/proj.git"
assert_eq "github.com/me/proj" \
  "$(cd "$repo" && HEADER_HOME="$sb/.header" "$RP" key)" \
  "https remote with credentials normalizes the same"

# ── path fallback when there is no remote ─────────────────────
sb="$(make_sandbox)"; repo="$sb/noremote"; mkdir -p "$repo"
git -C "$repo" init -q
k="$(cd "$repo" && HEADER_HOME="$sb/.header" "$RP" key)"
assert_contains "$k" "noremote" "no remote → key falls back to the repo path"
# round-trips through bind/get using the derived (non-overridden) key
( cd "$repo" && HEADER_HOME="$sb/.header" "$RP" bind path-topic "Local" )
assert_eq "path-topic" \
  "$(cd "$repo" && HEADER_HOME="$sb/.header" "$RP" get)" \
  "bind/get round-trip via the path-derived key"

# ── HEADER_HOME override is honored ───────────────────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/custom-home" HEADER_REPO_KEY="proj-a" "$RP" bind home-topic "H"
assert_eq "yes" "$([ -f "$sb/custom-home/repos.jsonl" ] && echo yes || echo no)" \
  "registry is written under HEADER_HOME"

t_done
