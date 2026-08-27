# Header reference — topics

*Loaded on demand by the Header skill; not part of the always-loaded SKILL.md.*

## First-run enrichment choice

The front door for a **new repo with no key** — referenced from SKILL.md ("First-run enrichment choice"). `<REPO>` is `header-repo`, `<AUTH>` is `header-auth`, both next to the preamble's `HEADER_BIN`.

**Fires only when** all hold: `ENRICH_MODE: unset`, `INTERACTIVE: yes`, `HAS_KEY: no`, `AUTO_REGISTER` ≠ `false`, `REPO_TOPIC`/`TEAM_TOPIC` empty, `SIGNUP_STATE` ≠ `public-only`. If any fails, skip this section (the standard Step 0 resolution / "After the audit" offer / Telemetry consent apply instead).

**Run the audit (Step 3) first** so the custom option can name the detected stack, then ask (`AskUserQuestion` on Claude Code; numbered plain text elsewhere) — asked **alone**, never bundled with the apply menu:

> I can enrich these recommendations two ways. **Generic** — the public agentic-coding briefing; nothing about your code leaves the machine. **Custom — tuned to this codebase** (I detected *\<one-line stack\>*): I set up a free Header trial and build a briefing for *your* stack. A one-line stack summary leaves the machine to create it — no code, no file contents. Switch or delete anytime.
>
> 1. **Custom — tuned to this codebase** (recommended)  2. Generic  3. Always custom  4. Always generic

Record the per-repo answer (and, on "Always …", the global default):

```bash
"<REPO>" enrich-mode custom            # or: generic   (this repo)
"<HEADER_BIN>" set enrich_mode custom  # only on "Always …" (global default for new repos)
```

### Generic (options 2 / 4)

`"<REPO>" enrich-mode generic`. Resolve the built-in public topics (SKILL.md Step 0, case 5), run Steps 1–2, present Step 4 enriched from them — exactly today's no-key behavior. Never register; nothing project-derived egresses. Continue to "Telemetry consent".

### Custom (options 1 / 3)

`"<REPO>" enrich-mode custom`. Custom needs a key — find out whether they already have one:

> Quick one — are you already a Header user?
>
> 1. **New to Header** (recommended — I'll set up a free trial, no signup)  2. I have an account — I'll paste my API key

**New →** register an anonymous trial account. Silent: only this device's id + os/arch/skill-version leave — no project data.

```bash
"<AUTH>" register
```

- **Exit 0** → a read+write key is saved to `~/.header/credentials` (umask 077) and the account is cached. Proceed.
- **Exit 1** (offline / 5xx / rate-limited) → tell the user once that custom setup didn't go through, fall back to the **Generic** path for this run, and **leave `ENRICH_MODE` unset** (don't record anything) so the next run re-offers. Never block the audit.
- **Exit 3** (a key already exists — shouldn't happen under this gate) → treat as already set up.

**Existing →** point them at their key and save it with the same hardened write:

> Open **Settings ▸ API Keys** at https://joinheader.com — create or copy a key with **read + write** access (`hdr_sk_…`; write is needed to create topics) — and paste it here.

Offer to open the URL (portable `open` / `xdg-open` / `start` — see the snippet under "After the audit"). When they paste:

```bash
"<AUTH>" save-key "PASTED_KEY"
```

An empty or declined paste → the same fallback as a failed register (generic this run, leave `ENRICH_MODE` unset).

**With a key now available**, build the repo's topic and defer the briefing. `<TOPIC>` is `header-topic`, next to the preamble's `HEADER_BIN`:

1. **Create + bind the topic — one deterministic command.** The Step 3 audit inferred the stack; draft the `name` + `goal_description` (that's the judgment call), then let the bin do the API dance:

   ```bash
   "<TOPIC>" create --name "<short topic name>" --goal "<goal_description drafted from the detected stack>"
   ```

   It POSTs the topic (default source group), **parses the nested response correctly, binds `topic.id` to this repo**, and prints `TOPIC_ID` / `GOAL_ID` / `BRIEFING_ID` — **capture `BRIEFING_ID`** (the `first_briefing_id`) to poll. **Don't hand-roll the curl/JSON:** the response nests three id fields (`topic.id`, `default_goal_id`, `first_briefing_id`) and a greedy grep binds the wrong one (the freshness check then `404`/`500`s) — that's the whole reason this is a bin. Exit codes: `0` ok; `2` no key (shouldn't happen — you just registered); `3` tier-gate (prints `ERROR_CODE <code>` → run "Tier limits and error handling"; rare on a fresh trial); `1` other → tell the user, fall back to generic for this run. Source tailoring (`sources/recommend`) is a later-run refinement — skip it here for speed.

2. **Present the audit now, then LAUNCH the briefing poll in the background.** Render Step 4's coach + scorecard + non-briefing recommendations immediately, with the briefing section reading: *"📰 Building this repo's briefing (the first one can take 30–40 min) — stack-specific recommendations will surface automatically when it's ready."* Then **actually launch the poll — do not just say "it'll land next run" and stop** (that leaves the user to remember to re-run; the whole point is it lands on its own):

   - **Claude Code:** run `"<TOPIC>" await <BRIEFING_ID>` as a **background job** — `Bash` with `run_in_background: true`. It polls every ~10 min (up to ~50 min) and re-invokes you when it exits. Handle the exit:
     - **0 (COMPLETED)** → `"<TOPIC>" get <BRIEFING_ID>`, cross-reference the **briefing-derived items only**, surface them — *"🔁 Your repo's briefing is ready"* — with their own small apply prompt, then record `"<REPO>" seen "<GENERATED_AT>"` (from `"<TOPIC>" latest`). **Then, at this payoff moment, fire the claim nudge:** if `ACCOUNT: anonymous-unclaimed` and `CLAIM_NUDGED: no`, run the "Claim your account (nudge)" pitch (SKILL.md) framed around the briefing they just got, and set its marker.
     - **5 (FAILED)** → tell the user; offer `"<TOPIC>" generate <GOAL_ID>` to retry.
     - **6 (still generating past the timeout)** → the topic is bound, so it lands on the next run here; say so in one line. The briefing won't surface in-session, so **fire the claim nudge now instead** (same gating + marker).
   - **Other harnesses / no background job:** skip the poll — the topic is bound, so the briefing-derived recs land on the **next** run in this repo (say so in one line). The briefing won't surface in-session, so **fire the claim nudge now** (same gating + marker).

3. **Chained offers during the wait** (they depend on the topic existing) — bind is done; make the **schedule** and **team-config** offers exactly as in "After the audit" steps 2–3 below.

Continue to "Telemetry consent". The claim nudge is handled in step 2 — at the briefing payoff, or as a creation-time fallback when the briefing won't surface in-session — so don't also nudge here. On a later run this repo has `ENRICH_MODE: custom` + a bound `REPO_TOPIC`, so Step 0 resolves it and the briefing already exists — no choice, no deferral.

## After the audit: customize your topic (existing key)

For a user who **already has a key** (`HAS_KEY: yes`) but no bound topic — the "First-run enrichment choice" gates on `HAS_KEY: no`, so it doesn't fire for them. Once the audit + recommendations are delivered **and the apply menu has resolved**, in interactive mode, offer to **tailor the enrichment topic to this repo**. This is its own separate question — never bundled as a second question inside the apply-menu `AskUserQuestion` call. The briefing that enriched the audit came from a generic topic; a custom topic targets sources about *your* stack.

**Conditions to fire** (all must hold):

- `INTERACTIVE: yes`
- `HAS_KEY: yes` (a no-key new repo is handled by the first-run choice above, not here)
- `TOPIC_OFFERED: no` for this repo
- `SIGNUP_STATE` is **not** `public-only` (back-compat — honors older opt-out markers from 0.10.0/0.10.1; this skill no longer writes new ones)
- `REPO_TOPIC` is empty (this repo isn't already bound to a custom topic)

If any of those fails, skip this section and go straight to "Telemetry consent".

Ask (`AskUserQuestion` on Claude Code; numbered plain text elsewhere):

> The recommendations above were enriched by Header's **general** agentic-coding briefing — the same source feed for everyone. A **custom topic** would tune the enrichment to *this* repo: sources and focus tailored to your stack, so every future audit pulls in items directly relevant to your code.
>
> Want one for this repo?
>
> 1. **Yes — customize for this repo** (recommended for repos you'll work in repeatedly)
> 2. Remind me next session
> 3. Not for this repo — don't ask again

There is **no global "never ask anywhere" opt-out** — declines are per-repo only. Each repo is its own decision; "not for this repo" silences only here. (`<REPO>` is `header-repo`, next to the preamble's `HEADER_BIN`.)

### 1 — Yes, customize

If `HAS_KEY: no`, walk through signup first:

> Custom topics need a Header account. About 30 seconds, no card.
>
> Sign up at https://joinheader.com/ — start the free trial → open **Settings ▸ API Keys** → create a key with **read + write** access (`hdr_sk_...`; write is required to create custom topics) → paste it here.

Offer to open the URL:

```bash
URL="https://joinheader.com/"
if   command -v open     >/dev/null 2>&1; then open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"
elif command -v start    >/dev/null 2>&1; then start "$URL"
else echo "Open $URL in your browser."
fi
```

When the user pastes a key, offer to save it under a tight umask:

> Save it to `~/.header/credentials` (readable only by you) so you don't re-enter it each session?

Replace `PASTED_KEY` with the key the user pasted:

```bash
_HH="${HEADER_HOME:-$HOME/.header}"; mkdir -p "$_HH"
( umask 077; printf 'HEADER_API_KEY=%s\n' "PASTED_KEY" > "$_HH/credentials" )
chmod 600 "$_HH/credentials" 2>/dev/null
case "$(ls -l "$_HH/credentials" 2>/dev/null)" in
  -rw-------*) printf 'done\n' > "$_HH/.signup-state"; echo "Saved — custom briefings are ready." ;;
  *) rm -f "$_HH/credentials"
     echo "Could not secure the file — not saving the key. Add this to your shell profile instead:"
     echo "  export HEADER_API_KEY=PASTED_KEY" ;;
esac
```

If the user defers (won't paste a key right now), record `pending` and skip the rest — next run will re-offer once:

```bash
printf 'pending\n' > "${HEADER_HOME:-$HOME/.header}/.signup-state"
```

The credentials file is **only ever read as data** (parsed via `grep`/`sed`); nothing sources or executes it.

**With a key now available**, build the custom topic — the Step 3 audit already inferred the stack, so draft the goal for them. For a sharper fit, first let Header propose sources: `POST /api/v2/sources/recommend` → `POST /api/v2/sources/recommend/commit` returns a `group_id`. Then create the topic (see "Create a custom topic"); the response includes `first_briefing_id` — generation runs **asynchronously**, typically a few minutes.

> Creating a topic focused on <one-line summary of the detected stack and priorities>. The first briefing is generating in the background (~3-5 min); while we wait, let me get a couple of things set up.

**During the server-side generation**, run the chained per-repo offers — fill the dead air with the questions that depend on the new topic existing. Order:

1. **Bind the topic to this repo.** `"<REPO>" bind <new_topic_id> "<topic name>"` — future runs here use it automatically as `REPO_TOPIC`.

2. **Offer a schedule** (if `SCHEDULE_OFFERED: no`):

   > Keep this repo's briefing fresh automatically? Header regenerates it server-side on cadence, so a new one is waiting next session.
   >
   > 1. Every 3 days  2. Every 7 days (recommended)  3. Every 14 days  4. Every 30 days  5. No thanks

   On a cadence → `PUT /api/v2/goals/{default_goal_id}` with `schedule_enabled: true`, `schedule_frequency_days: N` (see "Bound repos — freshness & schedule"). Confirm and `"<REPO>" flag schedule-offered set` regardless.

3. **Offer team config** (if `TEAM_CONFIG: none`, `TEAM_CONFIG_OFFERED: no`, and a `git remote` is configured — i.e., shared repo):

   > Share this topic with your team? I can drop a `.header/config` in the repo pinning this topic — commit it, and every teammate's `/header` uses it automatically with no setup. (Recommended for shared repos.)

   On yes → `"<HEADER_BIN>" team-init <new_topic_id>` writes `./.header/config`; surface the `git add` hint so the file reaches teammates. Always `"<REPO>" flag team-config-offered set`. See "Team config" for what keys are allowed.

4. **Poll for the first briefing.** When all offers are resolved, check briefing status (see "Polling IN_PROGRESS briefings"). When `COMPLETED`, surface one line — "✓ Your custom briefing is ready; next session here will use it" — and continue to "Telemetry consent". Don't re-deliver the audit; the next run picks up the new topic.

If briefing creation hits `TOPIC_LIMIT_FREE` or any other `*_FREE` code, run the trial/upgrade flow (see "Tier limits and error handling"). On `*_QUOTA`, surface it and continue (the existing audit still landed).

**Flip the per-repo flag** once the topic is created (or once the user finishes signup + topic creation in this flow). Do **not** flip it if the user picked option 2 or option 3 — those branches handle the flag themselves.

```bash
"<REPO>" flag topic-offered set
```

### 2 — Remind me next session

Don't flip the per-repo flag. Don't touch `SIGNUP_STATE`. The next session in this repo will re-ask with the same wording. Acknowledge briefly ("ok, I'll bring it up next time") and continue to "Telemetry consent".

### 3 — Not for this repo, don't ask again

Flip the per-repo flag — this repo never gets re-offered:

```bash
"<REPO>" flag topic-offered set
```

Other repos still get asked. Tell the user they can re-enable this repo with `header-repo flag topic-offered clear` if they change their mind. Public-default audits keep working unchanged.

### Resumption (deferred signup)

On a later run where `SIGNUP_STATE: pending` and `TOPIC_OFFERED: no`, re-offer with a softer pitch ("you started signup earlier — still want a custom topic for this repo?"). Same three options, same gating. The user can keep deferring as long as they want — option 3 ("not for this repo") is how they silence it.


