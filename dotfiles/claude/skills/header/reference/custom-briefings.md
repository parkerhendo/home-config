# Header reference — custom briefings

*Loaded on demand by the Header skill; not part of the always-loaded SKILL.md.*

## Browse public topics

List all public topics:

```bash
curl -s https://joinheader.com/api/v2/topics/public/catalog
```

Each entry has `id`, `name`, `description`, `subscriber_count`.

For a specific public topic's latest briefing (no key), let the bin resolve the nested ids (`<TOPIC>` = `header-topic`):

```bash
"<TOPIC>" latest --topic <topic_id> --public   # prints TOPIC_NAME / BRIEFING_ID / GENERATED_AT / GOAL_ID
```

Then read the briefing content: authenticated → `"<TOPIC>" get <briefing_id>` (markdown); public → `GET /api/v2/public/briefings/{briefing_id}` returns JSON, read its `summary` field.


## Custom briefings (API key required)

API reference for authenticated workflows. Most of this is wired into the audit-led flow above ("After the audit"); use this section for the underlying API contract.

### API key resolution

Each authenticated call needs the key. Run once at the start of any shell making an authenticated call:

```bash
[ -n "${HEADER_API_KEY:-}" ] || HEADER_API_KEY="$(sed -n 's/^HEADER_API_KEY=//p' "${HEADER_HOME:-$HOME/.header}/credentials" 2>/dev/null)"
export HEADER_API_KEY
```

Env first, then the credentials file — which is **parsed, never sourced**. If it resolves empty, tell the user no key is configured and route them through the post-audit signup flow.

### Tier limits and error handling

Authenticated endpoints return structured error codes on tier limits:

| Suffix | HTTP | Meaning | Recovery |
|---|---|---|---|
| `*_FREE` | 403 | Caller is on the free tier; action is Pro-only. | Ask the user — start the free **trial** (only if the error response includes `can_start_trial: true`) or **upgrade** directly to Pro. **Never auto-pick a path.** On *trial* → `POST /api/v2/billing/trial/start`, then retry. On *upgrade* → `POST /api/v2/billing/create-checkout`, parse the returned URL, open it (portable: `open` / `xdg-open` / `start`). |
| `*_QUOTA` | 429 | Paid tier but at the cap (e.g., 10 topics, 7 manual briefings per rolling 24 h). | Tell the user. Suggest: wait, delete a topic, or email `info@joinheader.com` if the use case justifies a higher cap. |

**Concrete codes:**

| Endpoint | Free-tier code | Paid-cap code |
|---|---|---|
| `POST /api/v2/topics/` | `TOPIC_LIMIT_FREE` | `TOPIC_LIMIT_QUOTA` |
| `POST /api/v2/goals/{id}/briefings` | `MANUAL_BRIEFING_FREE` | `MANUAL_BRIEFING_QUOTA` |
| `PUT /api/v2/topics/{id}` | `EDIT_FREE` | — |
| `PUT /api/v2/goals/{id}` | `EDIT_FREE` | — |

**`https://joinheader.com/docs` is the canonical source of current error codes and recovery flows.** Fetch the docs page on any unknown code:

```bash
curl -sS https://joinheader.com/docs
```

#### TOPIC_LIMIT_FREE recovery

`POST /api/v2/topics/` returns `403` with `error.code: "TOPIC_LIMIT_FREE"`; the response also includes `can_start_trial`. Ask:

> Custom topics need a Pro account, and you're on the free tier. Pick one:
>
> 1. **Start the free trial now** (recommended — no credit card needed)
> 2. Upgrade to Pro directly

`<AUTH>` is `header-auth`. **Trial** (if `can_start_trial: true`) — then retry the original request:

```bash
"<AUTH>" trial     # prints TRIAL_ACTIVE/TRIAL_ENDS_AT (exit 0); or ERROR_CODE + exit 3 if already used
```

**Upgrade** — checkout needs an email, so an **anonymous** account must claim first (`"<AUTH>" claim-url`); a claimed account can:

```bash
"<AUTH>" checkout --email <email>    # prints CHECKOUT_URL
```

Open the `CHECKOUT_URL` (portable: `open` / `xdg-open` / `start`, else print it). Upgrade is otherwise UI-only. The same trial-vs-upgrade pattern applies to any `*_FREE` code.

### Setup

Create an API key with **read + write** access from **Settings ▸ API Keys** at [joinheader.com](https://joinheader.com) — write is required to create custom topics:

```bash
export HEADER_API_KEY="hdr_sk_..."
```

### Create a custom topic

Before POSTing, ask whether to include any custom sources on top of the default source group:

> Add custom sources to this briefing topic? You can include additional RSS feeds, YouTube channels, Reddit subs, or existing Header source groups / source IDs alongside the default group (which covers AI agent frameworks, MCP, and coding tools).
>
> 1. **No, just the default sources** (recommended)
> 2. Yes — I'll provide them

Topics link **source groups**, not individual sources. The create body takes `source_group_ids` (min 1):

- Existing **source group IDs** → add to `source_group_ids` alongside the default.
- Individual **source IDs** or **new feed URLs** → put them in a group first ("Add a source"), then include that group's id. Or let Header propose a tailored group: `POST /api/v2/sources/recommend` (`topic_name`, `goal_description`) → `POST /api/v2/sources/recommend/commit` returns a new `group_id`.

```bash
curl -s -X POST https://joinheader.com/api/v2/topics/ \
  -H "Authorization: Bearer $HEADER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Project Briefing",
    "source_group_ids": ["64981a34-3b8b-4064-a391-22f4534c229b"],
    "goal_description": "Focus on developments relevant to [describe your project and tech stack]"
  }'
```

The default source group (`64981a34-...`) covers AI agent frameworks, MCP, coding tools.

**Response shape — parse it as JSON, not with grep.** The body is `{ "topic": { "id", "default_goal_id", "name", … }, "first_briefing_id" }` — the new **topic id is nested at `topic.id`** (a sibling of `first_briefing_id`, *not* top-level), and there are **three distinct id fields** in play (`topic.id`, `topic.default_goal_id`, `first_briefing_id`). Bind **`topic.id`** with `header-repo bind`; poll **`first_briefing_id`** for the async briefing. A greedy `sed`/regex will silently grab the wrong id — extract with a JSON parser. (There is no "list my topics" fallback: `GET /api/v2/topics/` is the web app, and the public `catalog`/`dashboard` won't show a brand-new private topic — so capture `topic.id` from *this* response.)

### Team config (`.header/config`) — share a topic with your team

The personal binding from "After the audit" lives under `~/.header/` — it never leaves the machine, so a teammate who clones the repo gets nothing. To share with everyone on the repo, commit a `.header/config` at the repo root.

The post-audit flow offers to scaffold this when a topic is created in a shared repo. To do it manually:

```bash
"<HEADER_BIN>" team-init <new_topic_id>     # creates ./.header/config with default_topic
git add .header/config && git commit -m "Add Header team config"
```

**Team-relevant settings only.** Because the file is committed, only the allow-list is honored: `default_topic`, `staleness_days`, `schedule_frequency_days`, `language`. Personal preferences and **anything consent-, code-, or egress-related** (`telemetry`, `auto_update`, `auto_tune`, `update_check`, `experiment_sync`, `aggregate_submit`) are **ignored** by design — `header-config team-show` makes its effective contents auditable.

**Precedence.** `TEAM_TOPIC` sits **below** a personal `REPO_TOPIC` and **below** any env var, but **above** the personal default. Same for `staleness_days` and `language`.

**Security.** The committed file is **read as data only** (`grep`/`sed`, never sourced); only allow-listed keys are honored.

### Bound repos — freshness & schedule

Runs at session start when the preamble echoed a non-empty `REPO_TOPIC` **or** `TEAM_TOPIC`. A `REPO_TOPIC` needs a key; a `TEAM_TOPIC` does **not** when its owner published it (see the keyless probe below). `<TOPIC>` is `header-topic`, next to `HEADER_BIN`.

**1. Freshness check — one command** (deterministic: fetch + parse the nested `latest_briefing` + compare to `header-repo seen`):

```bash
"<TOPIC>" latest                              # the bound REPO_TOPIC (needs a key)
"<TOPIC>" latest --topic <TEAM_TOPIC>         # a team topic, with a key
"<TOPIC>" latest --topic <TEAM_TOPIC> --public  # a team topic, NO key (published topics)
```

It prints `TOPIC_ID` / `GOAL_ID` / `BRIEFING_ID` / `GENERATED_AT` and `FRESH new|current|none`:

- **No key + a `TEAM_TOPIC`** → run the `--public` form (SKILL.md Step 0, case 3). A published team topic resolves with no auth; read its briefing from `/api/v2/public/briefings/<id>`. Only when this returns exit `4` is an API key genuinely required — don't say a key is needed before the probe fails.
- **Exit `4`** → the topic is private (no key) or deleted server-side. Tell the user; for a personal `REPO_TOPIC` run `"<REPO>" clear` and fall back to the default topic; for a `TEAM_TOPIC` **don't** clear — tell them to fix `.header/config` (or ask its owner to publish the topic).
- **`FRESH new`** → a new briefing since the user last visited this repo. Say so ("📰 New briefing for this repo, generated `<GENERATED_AT>`"), fetch it (`"<TOPIC>" get <BRIEFING_ID>`), enrich the audit via Step 2, then record it: `"<REPO>" seen "<GENERATED_AT>"`.
- **`FRESH current`** → nothing new since last visit. **`FRESH none`** → the topic has no briefing yet.

**2. Schedule** — handled inside the post-audit chain. To change/stop later: `PUT /api/v2/goals/{GOAL_ID}` with a new `schedule_frequency_days`, or `{"schedule_enabled": false}`.

**3. Trial expiry.** A lapsed trial doesn't break reads — the bound topic still resolves and its last briefing is still readable — but new generation is blocked. Detect it with `"<AUTH>" subscription` → an `EXPIRED yes` line (`<AUTH>` is `header-auth`), or a `generate`/topic write returning `*_FREE` with `can_start_trial:false`. On expiry, surface **once** — "Your Header trial ended; upgrade to keep this repo's briefing fresh: `<claim-url>` (claim + upgrade), or the billing portal if already claimed" — and **fall back to public-topic enrichment** for this run so the audit still runs enriched. Upgrade is UI-only; the skill never charges.

### Add a source

`/header add-source <url>` (or "add this source: <url>") feeds a URL into the user's topic. Requires a key. `<TOPIC>` is `header-topic`:

```bash
"<TOPIC>" add-source "<url>"                     # add to the bound topic's source group
"<TOPIC>" add-source "<url>" --group <group_id>  # or an explicit group you own
```

It previews (detects type), creates the source, and adds it to the group — printing `SOURCE_ID` / `GROUP_ID` / `TYPE` / `NAME`. **Exit `3`** means the target group isn't yours to edit (the bound topic uses the *shared* default group — the common case): this is the judgment branch the bin leaves to you — create a group you own (`POST /api/v2/source-groups/`), `PUT /api/v2/goals/{goal_id}` to attach it to the topic's goal, then re-run with `--group <that group>`. If the user has multiple topics, ask which. On a `*_FREE`, run trial/upgrade.

### Check briefing status & fetch

```bash
"<TOPIC>" status <briefing_id>   # IN_PROGRESS | COMPLETED | FAILED
"<TOPIC>" get <briefing_id>      # the full briefing as markdown (authenticated)
```

`get` returns rendered markdown (the authenticated path honors `Accept: text/markdown`). The **public** path returns JSON only — read the `summary` field directly, or use `"<TOPIC>" latest --topic <topic_id> --public` for the latest briefing id + `generated_at`.

### Polling IN_PROGRESS briefings

**Use `"<TOPIC>" await <briefing_id>` — don't hand-roll a poll loop.** It block-polls every ~10 min (up to ~50 min; `--interval`/`--timeout` to change) and prints a timestamped status line each poll. First briefings routinely take **30–40 min**, so it's built for that. Exit: `0` COMPLETED · `5` FAILED · `6` timed out (still `IN_PROGRESS`) · `2` no key. (`"<TOPIC>" status <id>` is the one-shot primitive underneath.)

**Claude Code — the standard mechanism (non-busy-wait):** launch `await` as a **background job** (`Bash` with `run_in_background: true`); it detaches and re-invokes you on exit. Then act on the exit code (COMPLETED → fetch + surface; FAILED → offer a retry; timed out → lands next run). This is what the first-run deferred-briefing pass (`reference/topics.md`) does. `ScheduleWakeup` at `interval` is an alternative if you'd rather the agent wake and do one `status` check.

**Blocking pattern** (a harness that can't detach, or you truly want to wait):

```bash
out="$("<TOPIC>" generate <goal_id>)"
bid=$(printf '%s' "$out" | sed -n 's/^BRIEFING_ID //p')
"<TOPIC>" await "$bid"      # blocks until COMPLETED/FAILED/timeout; no jq, no manual loop
```

**Other harnesses (no background job):** record `briefing_id`; the topic is bound, so the briefing lands on the next invocation (freshness check picks it up).

### Generate a new briefing

```bash
"<TOPIC>" generate <goal_id> [--max-entries N] [--max-age-days N]
```

Triggers a fresh briefing for the goal and prints `BRIEFING_ID` + `ETA_SECONDS`; then poll with `"<TOPIC>" status <BRIEFING_ID>`. `--max-entries` caps source entries; `--max-age-days` limits to the last N days (both optional). On a `*_FREE` (`MANUAL_BRIEFING_FREE`) it prints `ERROR_CODE …` and exits `3` → run trial/upgrade.

### Update a goal

```bash
curl -sS -w "\n%{http_code}" -X PUT https://joinheader.com/api/v2/goals/{goal_id} \
  -H "Authorization: Bearer $HEADER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"description": "Updated focus areas...", "keywords": ["MCP", "agent memory"]}'
```

### Sync an experiment (`POST /api/v2/experiments`)

Account-scoped, idempotent **upsert** keyed by `client_key` (`<installation_id>:<experiment_id>`) so re-syncing the same experiment as it progresses (defined → run → analyzed → merged) updates one record. Driven automatically by `header-experiment` on each lifecycle change when a key is present (and by manual `push`); this is the underlying contract. **Metadata only — never code, prompt bodies, override contents, or logs.**

```bash
curl -sS -w "\n%{http_code}" -X POST https://joinheader.com/api/v2/experiments \
  -H "Authorization: Bearer $HEADER_API_KEY" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "v": 1,
  "client_key": "<installation_id>:<experiment_id>",
  "skill_version": "0.14.0",
  "submitted_at": "2026-05-28T18:22:45Z",
  "experiment": {
    "id": "slim-claude-md-20260527-141627",
    "kind": "harness-change",            // harness-change | model-swap | generic
    "description": "Slim CLAUDE.md: compress 4 skill-redundant sections…",
    "status": "analyzed",                // defined | run | analyzed
    "replicates": 3,
    "non_inferiority_margin": 0.02,
    "commit_ref": "HEAD",
    "arms": [
      {"label":"A","model":"","role":"control","overrides":null},
      {"label":"B","model":"","role":"treatment","overrides":"arms/B"}
    ],
    "tasks": [
      {"id":"t1","title":"Add a briefing_count field to the v2 Goal model",
       "title_source":"derived","verify":"pytest tests/v2/ -x -q",
       "prompt_ref":"tasks/t1.md","prompt_sha256":"b2938df7…","prompt_bytes":308}
    ]
  },
  "hypothesis": {                        // present whenever a statement exists (it almost always does)
    "statement":"Slimming CLAUDE.md keeps success non-inferior at materially lower per-turn token cost",
                                          //   ↑ the full claim in words — the dashboard headline. The
                                          //     spec's `hypothesis:` field, falling back to `description`.
    "ledger_key":"slim-claude-md",       // ↓ provenance — blank unless the experiment traces to a finding
    "title":"Slim CLAUDE.md — 644 lines / ~9,739 tokens loaded every turn",
    "source_url":"https://www.youtube.com/watch?v=…",
    "disposition":"wanted"
  },
  "audit_basis": {"topic_id":"1991163f-…","goal_id":"","briefing_id":"3c9b6bbd-…"},
  "repo":    {"key":"github.com/me/repo","name":"repo","branch":"main","commit":"5214a29"},
  "machine": {"installation_id":"<uuid>","hostname":"…","os":"linux","arch":"x86_64"},
  "result":  { /* result.json verbatim: verdict, cost/success CIs, per_task — or null */ }
}
JSON
```

Expected success response (`200`/`201`): `{"id":"<server_id>","client_key":"…","url":"https://joinheader.com/experiments/<server_id>","status":"stored"}`. Surface the `url`. `goal_id` may be empty — the server can resolve the goal from `briefing_id` (a briefing belongs to a goal), or the client supplies it via `--goal`. Free-tier callers may get `EXPERIMENT_SYNC_FREE` (Pro-only) — run the trial/upgrade flow.

### Goal auto-tuning

Feed what the user applies/dismisses (the ledger) back into the goal so future briefings sharpen. Requires an API key + a custom goal; opt-in via `auto_tune`.

**Offer it once** when `<LEDGER> list --action applied --since-days 90` has 3+ entries, `auto_tune` is not already set, and no `~/.header/.autotune-offered` marker exists:

> You've applied several recommendations. Want Header to auto-tune this topic's focus from what you act on, so future audits get sharper?

On yes → `<HEADER_BIN> set auto_tune true`. Always `touch "${HEADER_HOME:-$HOME/.header}/.autotune-offered"`.

**When `auto_tune` is `true`** (key + custom goal exist), after delivering the audit, refine the goal from the ledger:
- Applied keys (`<LEDGER> list --action applied --since-days 90`) → add/emphasize keywords.
- Dismissed keys (`<LEDGER> list --action dismissed --since-days 90`) → de-emphasize.
- One `PUT /api/v2/goals/{goal_id}`, **merging** existing `keywords` / `description` (don't replace).

Best-effort: skip silently if no key, no custom goal, or no new signal. When you tune, say so. Tuning never blocks the audit.

### Since-last digest

For "what's new since I last checked" (and cron / `ScheduleWakeup` shapes): pass the last-run timestamp to surface only changes. `<TOPIC>` is `header-topic`:

```bash
_SINCE="$(cat "${HEADER_HOME:-$HOME/.header}/.last-run" 2>/dev/null || echo)"
"<TOPIC>" dashboard ${_SINCE:+--since "$_SINCE"}    # prints: TOPIC <topic_id> <next_action>
```

Surface topics whose `next_action` is `briefing_ready`; if none, say "nothing new since &lt;time&gt;" and stop. The skill writes `.last-run` after each audit.

### Scheduled / agent loop

For agents on a cron or scheduled trigger, `"<TOPIC>" dashboard --since <iso8601>` prints one `TOPIC <topic_id> <next_action>` line per custom topic (the server-computed `next_action`):

| `next_action` | Meaning | Behavior |
|---|---|---|
| `briefing_ready` | New completed briefing available. | `"<TOPIC>" latest --topic <topic_id>` → `BRIEFING_ID`; run the audit flow with it as enrichment. |
| `briefing_failed` | Most recent generation failed. | Tell the user; suggest re-trigger via `"<TOPIC>" generate <goal_id>`. |
| `briefing_in_progress` | Still generating. | Apply the polling cadence above. |
| `nothing` | No change since `?since`. | Skip. |

**Set `HEADER_NONINTERACTIVE=1`** in scheduled / unattended environments — the preamble reads it and suppresses every prompt (`CI=1` is treated the same way).

For full API documentation, see [joinheader.com/docs](https://joinheader.com/docs).


## Response Reference

> **Source of truth:** the field names, types, endpoints, and error codes here are a point-in-time snapshot. If the live API disagrees, **trust the API and fetch the latest contract from [joinheader.com/docs](https://joinheader.com/docs)** (e.g. `curl -sS https://joinheader.com/docs`, or the OpenAPI spec at `https://joinheader.com/api/v2/openapi.json`). Adapt to what the docs say; don't force the call to fit this snapshot.

### BriefingResponse

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Briefing UUID |
| `goal_id` | string | Parent goal UUID |
| `status` | string | `IN_PROGRESS`, `COMPLETED`, or `FAILED` |
| `summary` | string | Full markdown briefing text — **the content**; its "Key Insights" / bolded developments feed the Step 4 cross-reference |
| `key_developments` | string | JSON-encoded array, **typically empty in practice — don't depend on it**; read developments from `summary` instead |
| `source_articles` | array | Source articles used (title, url, metadata) |
| `estimated_duration_seconds` | int? | Server-computed ETA on the create response. Static — fixed at create time; compute remaining as `estimated_duration_seconds - (now - created_at)`. Null on completed/public briefings and pre-field briefings. |
| `source_count` | int? | Number of sources the ETA was based on. Null on completed/public briefings and pre-field briefings. |
| `stats` | object | Processing statistics (model, tokens, content window, etc.) |
| `is_public` | bool | Whether the briefing is publicly accessible |
| `created_at` | datetime | When generation was requested. Anchor for the remaining-ETA computation. |
| `generated_at` | datetime | When the briefing was generated |

### TopicCatalogItem

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Topic UUID |
| `name` | string | Topic name |
| `description` | string | What the topic covers |
| `source_count` | int | Number of source groups |
| `total_source_count` | int | Total individual sources |
| `subscriber_count` | int | Number of subscribers |

### ExperimentSyncResponse (`POST /api/v2/experiments`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Server-assigned experiment record id |
| `client_key` | string | Echoes the request's idempotency key (`<installation_id>:<experiment_id>`) |
| `url` | string | Web UI link to the synced experiment — surface this to the user |
| `status` | string | `stored` (created or updated) |

The request body is the `header-experiment push` payload documented under "Sync an experiment (`POST /api/v2/experiments`)". The receiving endpoint is **live** (it upserts on `client_key` and returns the web-UI `url` — surface it). A `404`/`405` from it now indicates a stale deployment or a proxy in the way, not a missing handler; the client's retry-on-next-edit behavior still applies.

