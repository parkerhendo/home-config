# Manual verification — audit-led flow (0.10.0+)

Verification checklist for the audit-led skill (state dir, `header-config`, `VERSION`,
the SKILL.md preamble, the audit + custom-topic flow, `install.sh`).

- The **test suite** proves the scripts (`header-config`, preamble logic, `install.sh`,
  version parity, ledger/telemetry/audit/cost helpers, update check).
- A **live `/header` run** proves the agent-interpreted onboarding (welcome, audit,
  custom-topic offer timing, install-missing refusal, non-interactive suppression) —
  the suite cannot.

You are verifying *our scaffolding* (preamble, config, onboarding, install, audit
flow), not the briefing content itself, which is Header's product. Live runs need
network to `joinheader.com`.

---

## Part 1 — Automated suite (30 seconds)

```bash
cd /home/workplace/Header-skill/header
./test/run.sh
```

- [ ] Output ends with `✓ all N suite(s) passed`

Each suite proves: `header-config` (get/set/list/defaults, key validation, sed-metachar
values, malformed files) · `preamble` (install-missing vs install-ok resolution,
`CI`/`HEADER_NONINTERACTIVE` → non-interactive, credentials read-not-sourced) ·
`version` (`VERSION` matches the `SKILL.md` frontmatter `version:`) ·
`install` (`install.sh` lands a working skill, idempotent, **removes a legacy
`header-briefing/` install at the same skills root**) · `audit`, `cost`, `ledger`,
`telemetry`, `update-check`, `repo` (the helper scripts).

---

## Part 2 — Poke the scripts by hand (3 minutes, optional)

```bash
cd /home/workplace/Header-skill/header
export HEADER_HOME=/tmp/hdr-verify && rm -rf "$HEADER_HOME"

bin/header-config get language          # → English   (built-in default)
bin/header-config set language Turkish
bin/header-config get language          # → Turkish   (now persisted)
bin/header-config list                  # file contents + active values
cat "$HEADER_HOME/config"                # the flat key: value file
bin/header-config badsubcommand; echo "exit=$?"   # → usage error, exit=1
```

- [ ] `get language` returns `English`, then `Turkish` after `set`
- [ ] `list` shows the keys with `(set)` / `(default)` markers
- [ ] `badsubcommand` prints usage and `exit=1`

```bash
rm -rf /tmp/hdr-install
HOME=/tmp/hdr-install /home/workplace/Header-skill/install.sh
ls /tmp/hdr-install/.claude/skills/header        # SKILL.md  VERSION  bin  test
/tmp/hdr-install/.claude/skills/header/bin/header-config defaults
```

- [ ] `install.sh` prints `Installed -> ...`
- [ ] The installed folder has `SKILL.md`, `VERSION`, `bin/`, `test/`
- [ ] The installed `header-config defaults` runs

### Migration from a 0.9.x install

```bash
rm -rf /tmp/hdr-migrate
mkdir -p /tmp/hdr-migrate/.claude/skills/header-briefing/bin
printf 'stale\n' > /tmp/hdr-migrate/.claude/skills/header-briefing/SKILL.md
HOME=/tmp/hdr-migrate /home/workplace/Header-skill/install.sh
ls /tmp/hdr-migrate/.claude/skills                # should list `header`, NOT `header-briefing`
```

- [ ] `install.sh` prints `Removed legacy -> .../header-briefing`
- [ ] `~/.claude/skills/header/` exists; `~/.claude/skills/header-briefing/` is gone

### Ledger & telemetry (scripts)

```bash
cd /home/workplace/Header-skill/header
export HEADER_HOME=/tmp/hdr-verify

bin/header-ledger record applied mcp-streaming --repo demo --title "MCP streaming"
bin/header-ledger status mcp-streaming --repo demo          # → applied
bin/header-ledger record dismissed mcp-streaming --repo demo
bin/header-ledger status mcp-streaming --repo demo          # → dismissed (latest wins)

bin/header-config set telemetry anonymous
bin/header-telemetry log skill_run --outcome success --recs-surfaced 2 --recs-applied 1
bin/header-telemetry sync --dry-run                          # the batch that WOULD be sent
```

- [ ] ledger `status` reflects the latest action (applied → dismissed)
- [ ] telemetry `sync --dry-run` shows the event but **no** `_repo` / `_branch`, and no `installation_id` (anonymous tier)

## Part 3 — Live test in Claude Code

### Setup

```bash
# a scratch project
mkdir -p ~/header-skill-test && cd ~/header-skill-test
printf '{ "name": "scratch", "dependencies": { "react": "^18.0.0" } }\n' > package.json   # optional

# install the skill for real
/home/workplace/Header-skill/install.sh

# sandbox the skill's state so it can be reset between scenarios
export HEADER_HOME=~/header-skill-test/.hdr-state
rm -rf "$HEADER_HOME"

claude        # launch a FRESH session in this dir (so it loads the updated skill)
```

Between scenarios, reset state by typing this in the Claude prompt (`!` runs a shell command):

```
!rm -rf ~/header-skill-test/.hdr-state
```

### Scenario A — first run, brand-new user

Run `/header`.

- [ ] A brief `👋 Header` welcome line appears **first**
- [ ] A **language question** follows, with `English` marked as **recommended**
- [ ] After picking a language, the skill **runs the audit** (harness + deps) and presents recommendations enriched by the public briefing
- [ ] **After** the audit, a 3-option question appears about customizing the topic for this repo (Yes / Not for this repo / No, don't ask again) — never before the audit

Pick **"No, don't ask again."**

- [ ] `!ls -A ~/header-skill-test/.hdr-state/` → shows `.welcome-seen`, `.language-prompted`, `.signup-state`
- [ ] `!cat ~/header-skill-test/.hdr-state/.signup-state` → `public-only`
- [ ] Running `/header` again shows **no welcome, no language prompt, no custom-topic offer** (each fires once)

*Optional:* pick `Spanish` or `Turkish` to confirm output gets translated; `!cat ~/header-skill-test/.hdr-state/config` should then contain `language: Spanish` (or whichever).

### Scenario B — "yes, customize" path

Reset state, run `/header`, reach the custom-topic offer, pick **"Yes — customize for this repo."**

- [ ] It shows the `joinheader.com` signup link and offers to open it
- [ ] It walks through creating an API key with **read + write** access (write is required for custom topics)
- [ ] Declining to paste a key now sets `.signup-state` to `pending`
- [ ] A later `/header` re-offers the custom-topic question once with a "you started signup earlier" softer pitch

### Scenario C — flow when a key already exists

Reset state, then simulate a saved key (no relaunch needed — the preamble reads this file):

```
!mkdir -p ~/header-skill-test/.hdr-state && printf 'HEADER_API_KEY=hdr_sk_testfake\n' > ~/header-skill-test/.hdr-state/credentials
```

Run `/header`.

- [ ] The audit runs and recommendations are delivered
- [ ] The custom-topic offer **still appears** (this is the first time for this repo) — but signup is **skipped**; it goes straight to "creating a topic" if accepted

### Scenario D — install missing (refusal)

Hide the `bin/` folder so resolution fails:

```
!mv ~/.claude/skills/header/bin ~/.claude/skills/header/bin.off
```

Run `/header`.

- [ ] The skill **refuses to run** and prints the reinstall notice (`HEADER_INSTALL: missing`)
- [ ] No briefing is fetched, no audit is attempted

Restore it:

```
!mv ~/.claude/skills/header/bin.off ~/.claude/skills/header/bin
```

### Scenario E — scheduled / non-interactive (regression guard)

Needs a fresh session — environment variables are fixed per `claude` launch. Exit Claude, then:

```bash
rm -rf ~/header-skill-test/.hdr-state
HEADER_NONINTERACTIVE=1 claude
```

Run `/header`.

- [ ] The audit runs and recommendations are delivered
- [ ] **No welcome, no language prompt, no custom-topic offer, no telemetry prompt** — onboarding fully suppressed (proves a cron / agent-loop run cannot be blocked by a prompt)

### Scenario F — update available (simulated endpoint)

Quickest check is the script alone (no Claude needed):

```bash
HEADER_HOME=/tmp/h-upd HEADER_VERSION_JSON='{"latest":"99.0.0"}' \
  ~/.claude/skills/header/bin/header-update-check
# → UPDATE_AVAILABLE <your-version> 99.0.0
```

For the full agent flow, exit Claude and relaunch with the simulated response:

```bash
rm -rf ~/header-skill-test/.hdr-state
HEADER_VERSION_JSON='{"latest":"99.0.0","message":"Test update"}' claude
```

Run `/header`.

- [ ] Right after the preamble (before the audit) the skill reports v99.0.0 is available and offers Yes / Always / Not now / Never
- [ ] **Not now** → no re-prompt this session; `!cat ~/header-skill-test/.hdr-state/update-snoozed` shows `99.0.0 1 <epoch>`
- [ ] Relaunch with `HEADER_VERSION_JSON='{"latest":"99.0.0","min_supported":"99.0.0"}'` → the skill reports an update is **required** (non-optional)
- [ ] With `update_check` set to `false` → no update prompt even with the simulated response

### Cleanup

```bash
rm -rf ~/.claude/skills/header ~/.codex/skills/header ~/header-skill-test
rm -rf /tmp/hdr-verify /tmp/hdr-install /tmp/hdr-migrate /tmp/h-upd
unset HEADER_HOME HEADER_VERSION_JSON
```

---

## What each step proves

| Step | Confirms |
|---|---|
| Part 1 | `header-config`, preamble logic, `VERSION` parity, `install.sh` (+ legacy-removal migration), audit/cost/ledger/telemetry/update/repo helpers |
| Part 2 | The scripts behave by hand; `install.sh` produces a working install and removes a legacy `header-briefing/` |
| Scenario A | Welcome + custom-topic offer exist; offer fires **after** the audit; marker-gated once-only per repo |
| Scenario B | Custom-topic "yes" branch; signup walkthrough; `pending` state + resume |
| Scenario C | `HAS_KEY` detection → signup skipped; credentials file read as data |
| Scenario D | Install-missing refusal — no fallback flow, clear reinstall instruction |
| Scenario E | Non-interactive guard — the mandatory regression test, live |
