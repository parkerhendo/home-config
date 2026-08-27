# Header reference — experiments

*Loaded on demand by the Header skill; not part of the always-loaded SKILL.md.*

## Experiments (`header-experiment`) — beta

> **Beta — the experiment loop** (Phase 2 of `docs/experiments-design.md`). Locally A/B-test a harness change (prompt-debt deletion, model swap, etc.) on the user's own tasks: paired-by-task bootstrap CI on per-task cost differences, with success non-inferiority as the merge gate (§6.5). Local-only — every run executes in an isolated `git worktree` and nothing leaves the machine. **Scope:** `mine` (git-history task mining + tests-oracle verifier, §11), `new` (audit-aware scaffolder), `validate`, `run` (`--aa` noise-floor; `setup:`/`teardown:` ephemeral infra), `analyze`, `report`, `merge` (apply arm B after a B-wins verdict). **Not yet:** σ-based power analysis, LLM judges, cross-customer aggregate submit.

### Mine tasks from git history (`mine`) — no hand-authoring

The friction that stopped "continuous" was that `new`/`define` still need the user to write the task **prompt** and name the **verify** command. `mine` removes both (design §11): a real repo already ships its correctness oracle — its **test suite** — and its **git history** is a factory of (task, oracle) pairs. Every commit that fixed code *and* touched tests is a task: check out the **parent**, re-apply only that commit's **test files** (so the new tests fail), and the job becomes "make the suite pass," graded by the repo's own suite. Nobody hand-writes a grader; the human who made the commit already did.

```bash
header-experiment mine <id> --list                       # preview candidate commits (no runs, no writes)
header-experiment mine <id>                              # validate + write a runnable model-swap experiment
header-experiment mine <id> --from <model> --to <model>  # set the A/B arms (default: opus-4-8 vs sonnet-4-6)
```

What it does: scans the last `--limit` commits for fixes touching source + tests (≤ `--max-files`), then **validates** each by checking out the parent, re-applying the fix's test files, and running the suite — keeping only those that **fail** (a real fix exists). Validation **narrows auto-detected runners** (`pytest -q`, `go test ./...`) to each candidate's re-applied test paths — much faster on a big suite, and more precise (an unrelated broken test can't masquerade as a real fix); `--full-validate` forces the whole suite, and the mined spec's *runtime* oracle is always the full suite either way. It writes a complete experiment whose tasks each pin the fix's parent `commit` and carry `apply_from`/`apply_paths`/`lock_paths`; at run time the runner applies the tests before the agent and **re-locks them before grading**, so "make the test pass" can't be won by editing the test (the reward-hacking defense). The default arms are a **model swap** — this is the keystone for "model-routing experiments at scale," the moat's first named learning: *is the cheaper model good enough on this repo's own real fixes?*

**This is the recommended way to start a model-swap experiment** — far less friction than authoring tasks. Reach for `new --kind model-swap` only when you want to test on a *specific* task you have in mind rather than mined history.

### Engine adoption (`mine --adopt`) — "should you move to this model?"

`mine --adopt` is `mine` with the engine-adoption question pre-wired: it detects the model **and effort** the user runs today (arm A), pits it against a target (arm B, default `claude-fable-5 @high`), and writes a `kind: engine-swap` experiment. It's the rung-3 proof behind the engine-adoption card (`/header fable-5`, `/header opus-4.8`). No separate verb to learn — it's the `mine` you already know, plus a flag.

```bash
header-experiment mine --adopt                  # A = your current engine, B = fable-5 @high
header-experiment mine --adopt --sweep          # + offer a 3rd arm at xhigh (the effort frontier)
header-experiment mine --adopt --to claude-opus-4-8                                    # the same-price move
header-experiment mine --adopt --to <model> --from <model>[@effort] --effort <level>   # override
```

Why model **and** effort: the System Cards' recurring headline is that the newer engine at a *lower* effort matches or beats the prior one at a *higher* effort (Fable 5 at medium beats every model at any effort on FrontierCode; min-effort 4.8 ≈ max-effort 4.7 on SWE-bench Pro) — and for Fable 5, whose token price is 2× Opus 4.8, the effort drop is what makes the per-task cost story work at all. Only a model+effort A/B can surface that. **2-arm by default; `--sweep` offers a 3rd arm** at the next effort up (interactive y/N on a TTY). For a swept (≥3-arm) experiment, **`report <id> --frontier`** is the one-command synthesis: it analyzes every arm vs the control and prints the cheapest arm that holds quality (the effort frontier), with the `merge` command to apply it. (Under the hood the analyzer is pairwise — `analyze`/`report --vs C` give a single A-vs-C comparison into a side `result-vs-C.json`; the canonical `result.json` stays the A-vs-B.) Detection reads `ANTHROPIC_MODEL` → settings `model` → the **most recent model in the user's transcripts** (what actually ran); only if all are empty does it assume `claude-opus-4-7` and **say so** (pass `--from` to correct — arm A is the control). When `merge` finds a B-wins engine swap it **offers to write** `model` + `effortLevel` into `.claude/settings.json` (shows a diff, asks first; `max` stays advisory). The proof needs a git repo (it mines real fixes); outside one, point the user at the card.

Scope honesty (state it when you surface results): mine's per-candidate check confirms the new tests *fail at the parent* (a FAIL_TO_PASS exists); it relies on `run --aa` to expose flaky/baseline-broken tasks (a task arm A can't pass either). The suite runs in a bare `git worktree`, so dep dirs (`node_modules`, `.venv`, …) are auto-symlinked via `worktree_include`; if validation finds nothing, the suite usually needs a build/env the worktree lacks — pass a `--verify` that runs standalone. Tier-1 proves correctness on covered behavior, not taste — don't overclaim.

**Worktree-isolation requirement (a real footgun).** mine (and the A/B run) only measure the *worktree's* code. A **PEP 660 editable install** — `pip install -e .` with a modern backend installs a `sys.meta_path` finder pinned to ABSOLUTE source paths — or any globally-installed copy of the package **defeats this**: inside every worktree, imports resolve to your *current* tree, not the checked-out parent/arm. mine now detects the signature (every candidate's re-applied tests PASS at its parent → it stops early and names the cause) instead of churning the whole suite for nothing. `worktree_include: venv` does **not** fix it (the finder's paths are absolute). The fix is to make the install path-based: `pip install -e . --config-settings editable_mode=compat` (revert with `pip install -e .`), or run mining inside a per-worktree venv. If you don't fix it, a later A/B would silently test the parent repo's code in both arms — the worst false "no difference."

### From audit finding to scaffolded experiment

The audit's `[Experiment]` findings are the input. When the user says "let's test that" on a finding, **don't make them retype what the audit already knows** — call `header-experiment new --kind ...` with the finding's payload pre-filled. The wizard auto-detects the verify command from the project's manifests (`package.json` → `npm test`, `Cargo.toml` → `cargo test`, etc.) and only asks for the one bit the audit can't infer: **which task to run the agent on**.

Concrete invocations by finding kind:

- **Prompt-debt deletion** (a `HIT` from `header-audit harness` — cargo-cult lines in `CLAUDE.md`/`AGENTS.md`):
  ```bash
  header-experiment new "<ledger-key>-$(date +%Y%m%d-%H%M%S)" \
    --kind prompt-debt-deletion \
    --file <relative-path-from-HIT> \
    --lines <line1,line2,...> \
    --description "<short title>" \
    --ledger-key <key> \
    --task <task-prompt-or-path> \
    --verify <verify-cmd>
  ```
  Arm A = current state. Arm B = the file with those lines stripped (the wizard does the sed for you and writes `arms/B/<file>`). **The verify task must exercise the deleted lines** — see the discrimination gotcha below; a generic `npm test` won't catch adherence drift.
- **Model swap** (audit/briefing-derived: "consider routing this task class to a cheaper model"):
  ```bash
  header-experiment new "<ledger-key>-$(date +%Y%m%d-%H%M%S)" \
    --kind model-swap \
    --from <current-model> \
    --to <proposed-model> \
    --description "<short title>" \
    --ledger-key <key> \
    --task <task-prompt-or-path> \
    --verify <verify-cmd>
  ```
- **Other** (major dep upgrade, behavioral rewrite — anything where you need to construct arm B's overrides by hand): fall back to the generic flow:
  ```bash
  header-experiment new "<id>" \
    --arm A:<current-model> --arm B:<proposed-model>:arms/B \
    --task <path-or-inline> --verify <cmd>
  ```
  Then prepare `~/.header/experiments/<id>/arms/B/` with the override files (copied into the worktree before the agent runs).

`--task` accepts either a path (resolved relative to the repo first, then the experiment dir) or a one-line inline prompt (written to `<exp_dir>/tasks/tN.md`). **`--task` is repeatable** — for crisper CIs target ≥3 tasks (the bootstrap CI's noise floor drops sharply moving from N=1 to N=3 to N=5). If you have real prior task transcripts or recent feature specs in the repo, use those — more realistic measurement than synthetic prompts.

**Power tiering.** Analyses below 5 paired tasks aren't refused — they're caveated. N=1 paired-by-task is genuinely degenerate (CI is a single point); N=2-4 is wide-but-honest and surfaces a `WIDE CI / LIMITED POWER` flag in the report. **For an A/A noise-floor check with only 1 task × K replicates**, the runner switches to a within-task replicate-level bootstrap automatically, which gives real bias-detection power without needing multiple tasks.

**Worktree isolation gotcha.** `git worktree add` only brings *tracked* files. If your verify command needs `venv/`, `node_modules/`, `.env`, or editable-installed packages, set `worktree_include: venv, .env, ...` in the spec — those paths get symlinked from the repo into each run's worktree. Without it, verify may silently test the parent repo's code instead of arm B's edits (the worst kind of false success).

**Sealed history — `seal_history:` (on by default).** `mine` derives tasks *from* git history, and a `git worktree` keeps a `.git` pointer into the parent repo's object store — so without sealing, the agent under test can run `git log --all` / `git show <sha>` and read the very commit that solves its task. (Databricks calls this "cheating by reading the answer from git" and seals the working copy per eval run.) Each replicate therefore gets a **single-root-commit workspace**: git still works for the agent (`status`, `diff`, `commit`), but no prior or future commit is reachable. The grade-time test lock keeps working — the locked paths are snapshotted out of the repo *before* sealing, so `lock_paths` never needs the object store the agent no longer has. Sealing failures **abort the replicate** rather than silently produce an invalid measurement. Opt out with `seal_history: off` in the spec's **top block** (above the first `[arm:…]`/`[task:…]` — `spec_get_scalar` ignores scalars below a section) or `HEADER_EXPERIMENT_NO_SEAL=1`; only do so for a task that genuinely needs history (e.g. "revert commit X"), and distrust any mined-task result produced with it off.

**Stateful experiments — `setup:` / `teardown:` (ephemeral infra).** `worktree_include` handles *files*; a DB-touching task needs an *isolated service*, not the repo's real database. Add `setup:` (a shell command) to the spec's top block: its stdout `KEY=VALUE` lines are captured and exported into every run's **adapter and verifier**, so the agent and the oracle both hit a throwaway DB/branch — never prod or beta. `teardown:` destroys it and is **guaranteed to run** (an `EXIT`/`INT`/`TERM` trap fires it even on Ctrl-C). `setup_scope:` is `experiment` (provision once for the whole matrix — fine for read-only or self-resetting tasks) or `run` (provision + tear down per `(task, arm, rep)` — required for **write-heavy** tasks, where one run's writes would otherwise contaminate the next; this multiplies infra churn, so guaranteed teardown matters). Example: `setup: neonctl branches create … -o json | jq -r '"DATABASE_URL=" + .connection_uris[0].connection_uri'` with a matching `teardown: neonctl branches delete …`. **Footgun:** a `DATABASE_URL` you inject this way is **shadowed by a `.env` you symlinked via `worktree_include`** if the app reads `.env` over the process env — have `setup` write the `.env`, or don't symlink it. Tool-managed provisioning is also how you avoid the "is this connection string the throwaway or prod?" guessing game — never hand-edit `.env` and eyeball endpoint IDs.

**Discrimination gotcha (prompt-debt deletions) — the deletion-side twin of the worktree trap.** A trim experiment only measures something if the verify task *exercises the trimmed instruction*. Delete a `MUST self-verify` line, then run a task that never needed self-verification, and you get "3/3 both arms" — which proves the task was easy, not that the cut was safe. The failure is on **both** axes, not just cost: the cost CI is sub-noise *and* the success rate is non-discriminating, so no outcome of the experiment can move the decision. Worse, a regression-style verify (`npm test`) is **blind to adherence drift** — the suite passes in both arms even if arm B quietly stops obeying the rule. Before running, ask: *would this task plausibly fail if the agent ignored the deleted lines?* If no, the experiment can't see its own risk — either pick a task that **requires the instruction to fire**, or treat the change as `[Apply with review]` (the diff is the evidence). Infra-dependent mandates ("self-verify via curl", "visual-check the page") need the **stack brought up inside the worktree** — that's a *supported* path, not a dead-end: `worktree_include` symlinks the files, and per-experiment ephemeral DBs/branches come from the `setup:`/`teardown:` lifecycle above. It carries a real wall-clock + provisioning cost, so weigh it — don't reflexively bail to `[Apply with review]` just because infra is involved. Stack-up is necessary but **not sufficient**, though: if the run adapter (often a one-shot headless invocation) doesn't actually *perform* the mandated work, arm A's cost collapses onto arm B's and you get a false "the mandate is free" — the **cost** axis goes non-discriminating exactly as the success axis can. `validate` and `run` print this warning automatically when an arm trims a `CLAUDE.md`/`AGENTS.md` — detected by diffing the override against the repo, so **hand-rolled specs are caught too** — and escalate when the deleted text carries emphatic mandates (`MUST`/`NEVER`/`ALWAYS`).

**Guardrail-value questions ("is this mandate earning its cost?").** Don't reach for an A/B. The question decomposes into *cost* (cheap — measure **one** real execution of the mandated work) and *benefit* (tail-risk insurance: the rate it prevents a bug that would otherwise ship × that bug's cost). A small-N A/B can't estimate a rare-event rate, and — per the cost axis above — a headless adapter often won't even incur the cost, so the run comes back falsely "free." Default to **measuring one execution's cost directly and reasoning about the benefit qualitatively**, keeping the guardrail unless the cost clearly isn't worth the protection. `new --kind prompt-debt-deletion` and `report` surface this recommendation when the deleted text is an emphatic mandate.

After the scaffold prints, walk the user through the four-step loop:

```bash
header-experiment validate <id>                      # lint
header-experiment run <id> --aa                      # noise-floor check FIRST (§3) — must be clean
header-experiment run <id>                           # the A/B (--jobs N parallelizes (task,rep) blocks;
                                                     #  arms stay sequential per pair, so pairing holds)
header-experiment analyze <id> && header-experiment report <id>
```

Surface these points when interpreting the report:
- The CI on **B − A cost** (per-task paired bootstrap, 95%) is the effect — the diff itself is meaningless without it.
- **Decision rule** (§6.5): merge B iff the cost CI's upper bound is below 0 AND success-rate diff's lower CI bound is ≥ −δ. Anything else is **"no proven win"**, not "B wins."
- **Conservative savings rate** (= `max(0, -upper_CI(diff_cost))`) is the figure that survives an audit — never quote the optimistic tail.
- A **noisy A/A** (CI excludes 0) means the harness is biased — *fix the harness before trusting any A/B*. This is the most common silent failure mode.
- **Agent-error rows (timeout / crash) are excluded from cost means but count on the success axis** with the verifier's verdict — a flaky arm can't look non-inferior by crashing its way out of the sample. The report shows both pairings ("N cost / M success") when they differ.

The runner spends real tokens — the cost gate confirms before launching. Don't auto-`--yes` for the user. Even with `--yes`, the runner still prints the full cost/power disclosure (it skips the confirmation *prompt*, not the disclosure), and if a prior `--aa` result exists it surfaces the **measured noise floor** at the A/B gate — so an effect smaller than the harness's own run-to-run noise is visible *before* the spend, not discovered at `analyze`.

On a B-wins verdict, `header-experiment merge <id>` applies arm B's overrides to the repo — it shows the unified diff first, asks for confirmation, refuses any non-B-wins verdict unless `--force`, and prints a suggested `git commit` with the `Header-Audit-Finding:` trailer when the experiment came from an audit finding. It does **not** auto-commit; you retain the final say.

### Sync experiments to your account — beta, opt-in (ships off)

Experiments sync to the user's Header account so they show up in the web UI — a live-updating record of *which experiment, testing which hypothesis, from which goal/topic/briefing, on which repo and machine, and how it came out*. Nothing runs server-side; the runner stays local. This is the user's own identified dashboard, distinct from the (still-anonymized, still-future) cross-customer aggregate submit.

**Egress is opt-in.** `experiment_sync` ships **`off`** — matching the telemetry/consent posture, so account egress is never a default the user has to discover and disarm. Set `header-config set experiment_sync auto` to turn it on; thereafter every lifecycle change — `new`, `define`, `validate` (the "I edited the spec" hook), `run`, `analyze`, `merge` — fires a background sync, gated on:

- **`experiment_sync` is `off` (default)** → no sync, no per-experiment nudge. Silent and local. If the user asks to connect a dashboard, point them at `experiment_sync auto`.
- **`experiment_sync auto` + `HAS_KEY: yes`** → the tool syncs and prints a faint `⤴ dashboard: …` status line. **Don't ask permission per edit** — configuring a key + opting into `auto` is the consent. Surface the line if useful; mention the dashboard URL on success.
- **`experiment_sync auto` + `HAS_KEY: no`** → the tool prints a one-time per-experiment recommendation to connect an account. **Reinforce it** — route through the post-audit signup flow — but never block the experiment. Recommend, don't require.

The lifecycle `status` (`defined → run → analyzed → merged`) is part of every sync, so the UI shows each experiment's last-known state. A local `~/.header/experiments/<id>/.last-sync` marker (`<iso> <http_code>`) records the last sync result for offline inspection.

**Opt-out.** `header-config set experiment_sync off` disables all auto-sync (manual `push` still works); `HEADER_EXPERIMENT_NOSYNC=1` disables it for one invocation / CI. `experiment_sync` is **personal-only** — a committed team config cannot turn it on for teammates.

**The privacy contract — say it plainly.** Sync sends metadata only: the experiment id/kind/description, arm models + override **paths** (not contents), task **titles** + a sha256 + byte count, the hypothesis (the full claim in words, plus its audit-finding provenance), the topic/goal/briefing it traces to, the repo's git-remote identity + commit, the machine (install id + hostname/os/arch), and the analyzed result (verdict + CIs). **Task prompt bodies, override file contents, and agent logs never leave the machine.** Task titles resolve authored → derived → id: if a `[task:…]` block has a `title:` line you (or the user) wrote, it's sent verbatim (zero-leak); otherwise a one-line summary is *derived* from the prompt's first heading (descriptive, low-leak); otherwise the task id is the floor. **If the prompt's first line could embed sensitive specifics, author a `title:` first** so the synced label is one you control.

**Help the lineage along.** The hypothesis *statement* (the dashboard headline) is the spec's own `hypothesis:` field — falling back to `description` — so it syncs directly and never depends on the ledger. Set it at scaffold time with `--hypothesis` (`new`/`define`), or edit the spec. The audit-finding provenance (title + source_url + disposition) and the topic/briefing are recovered from the recommendation ledger via the spec's `ledger_key`. When the session resolved a topic/goal/briefing the ledger doesn't have, a manual `push` can supply them (flags win over the ledger):

```bash
header-experiment push <id> --topic <topic_id> --goal <goal_id> --briefing <briefing_id>
header-experiment push <id> --dry-run    # print the exact JSON payload (no key needed)
header-experiment push --all             # sync every local experiment now
```

**Errors (auto-sync is always best-effort).** No key → recommend + skip (never an error). `404`/`405` → unexpected now that the endpoint is live — usually a stale deployment or a proxy in the way (or a `HEADER_API_BASE` override); the status line says so, the experiment is safe locally, and it retries on the next edit. A `*_FREE` code → dashboard sync is Pro; run the trial/upgrade flow (see "Tier limits"). Sync never blocks or fails the experiment loop.

### Aggregate submit — the proven-changes library (beta, opt-in, anonymized)

The cross-customer pool behind `PROVEN` lines (design §7.3): each consenting user contributes the **anonymized effect size** of an analyzed experiment, and the library serves the pooled evidence back through briefing-supplied 6-field patterns — so a change one user proved becomes "[proven across N repos]" in everyone's audit, and nobody re-runs a $60 A/B for a change the pool already measured. **Distinct from account sync** (`push` is the user's own identified dashboard): aggregate carries **no identity at all**.

```bash
header-experiment aggregate <id> --dry-run   # preview the exact payload (nothing sent)
header-experiment aggregate <id>             # asks y/N (or --yes); needs an analyzed result
<HEADER_BIN> set aggregate_submit on         # opt in: auto-submit after each analyze
```

**The privacy contract — stronger than sync's.** Sent: change kind, the **curated** category (the ledger key only when it names a known pattern id — user-typed keys never leave), ecosystem label, harness, task class, verifier tier, arm engines (public model ids + effort), N/replicates/δ, and the result's verdict + means + CIs (`per_task` is stripped — mined task ids embed commit shas). Never sent: installation id, hostname, repo identity, prompts or hashes of them, override paths, or any free text (`description`/`hypothesis` stay local). The POST is **unauthenticated by design** — identity stays off the wire entirely; the server applies small-cohort (k-anonymity) protections before serving pooled claims. `aggregate_submit` is **personal-only** — a committed team config cannot enable it. Default **off**; `HEADER_EXPERIMENT_NOSYNC=1` disables it for one invocation/CI. _(The receiving endpoint is landing server-side; until then the call exercises the contract and records the attempt in `.last-aggregate`.)_


