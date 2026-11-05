---
name: shim
description: Set up, restore, or tear down temporary local client-side shims so the current branch's UI change is visible in the local app. Use when a UI change cannot be seen locally because the backend, feature flag, or seed data does not produce the required state; when the user asks to "shim", "fake", "stub", or "force" a state locally for review or screenshots; when the user asks for a shim used in an earlier session (torn-down shims are archived under `.agents/shims/` for restore); and when the user asks to remove, revert, or clean up a shim, or a stale `temp-*` module from an earlier session is breaking typecheck or lint.
argument-hint: [optional-route-or-state-to-force]
---

# Shim

Make the UI change on the current branch visible in the local app (`http://localhost:3000/`) by adding temporary, clearly-labeled client-side shims: fabricated API data, forced conditional branches, and stubbed mutations. The goal is a reviewable, screenshottable local UI — not working backend behavior.

Shims are throwaway code. They are never committed with the feature and must be trivially removable — write every shim so that Step 7 can undo it in a couple of commands.

Step 0 restores a previously archived shim; Steps 1–6 build one from scratch. **If the user is asking to remove a shim, or a stale `temp-*` module is breaking the build, skip straight to Step 7.**

## Step 0: Check the stash

Torn-down shims are archived under `.agents/shims/<topic>/`, one directory per shim:

- `temp-<topic>.ts` — the shim module as last used.
- `wiring.patch` — the call-site diff that wires the module in.
- `NOTES.md` — the route to view, the scenario switch, and any flag or environment prerequisites.

Before authoring anything, `ls .agents/shims/`. When a matching topic exists, restore it instead of rebuilding:

```bash
cp .agents/shims/<topic>/temp-<topic>.ts utils/
git apply .agents/shims/<topic>/wiring.patch
```

If the patch no longer applies, re-wire the call sites by hand from the patch — the data module is the expensive part and usually still valid. If the module no longer typechecks against current types, update it rather than starting over. Then jump to Step 5 to verify, and follow `NOTES.md` for prerequisites.

The stash is local-only and must never be committed: keep `.agents/shims/` listed in `.git/info/exclude`.

## Step 1: Understand the change

Do not guess at the intended UI. Gather evidence first:

1. `git diff main...HEAD --stat` and `git log main..HEAD --oneline` for the shape and story of the branch.
2. `git diff main...HEAD` on the components that render the new UI.
3. `git status` for uncommitted work, including shims that already exist.
4. The associated PR, which usually carries the clearest statement of intent:
   ```bash
   gh pr list --head "$(git branch --show-current)" --state all --json number,title,body,url
   gh pr view <number> --json title,body,comments
   ```
   If no PR exists on the branch, check for a PR that mentions the branch or the feature, and read the commit bodies (`git log main..HEAD`) instead.

From that evidence, write down for yourself:

- What the user should see that they cannot see today.
- Which component renders it, and which route reaches that component.
- The exact condition gating it: API field values, a feature flag, a count, a state enum, an entitlement.

## Step 2: Identify the gate

Trace the gating condition to its source. The gate is almost always one of:

| Gate                                     | Where it lives                                                          | Shim approach                                                                |
| ---------------------------------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| API response shape or values             | SWR hook, `getServerSideProps`, or loader data                          | Transform the fetched data in a `temp-*` helper                              |
| Feature flag                             | `useFeatureFlags` / `useIsFeatureEnabled` in `app/lib/feature-flags.ts` | Prefer enabling the real flag; override locally only if that is not possible |
| Empty or wrong seed data                 | Local API / database                                                    | Fabricate records in a `temp-*` helper                                       |
| Mutation result                          | `POST`/`PATCH` handler                                                  | Stub the submit callback and set local state optimistically                  |
| Derived state (counts, versions, timing) | Component logic                                                         | Compute the desired values in a `temp-*` helper                              |

Prefer shimming at the **data boundary** (right after data arrives) over shimming inside render logic. Data-boundary shims exercise the real component code, so what you see is what reviewers will get.

## Step 3: Write the shim

Shim conventions:

- One module per shim: `utils/temp-<topic>.ts`.
- Exported function named `temp<Topic>`, taking the real data and returning the shimmed data.
- Type the input and output with real types from their defining modules. No `any`, no assertions.
- Follow the target repository's coding conventions and nearby code.
- Keep the call site to a single line, memoized where the real data was memoized:
  ```ts
  const experimentRows = useMemo(() => tempExperimentRows(rows), [rows]);
  ```
- Do not delete or rewrite the real code path. Wrap or replace its input, so removing the shim restores the original behavior.
- Keep shimmed values realistic. Real-looking versions, names, timestamps, and counts. Nonsense data hides layout and truncation bugs.

For a flag gate, trace `useFeatureFlags` / `useIsFeatureEnabled` in `app/lib/feature-flags.ts` and prefer the existing local flag controls. Do not change shared LaunchDarkly configuration just to preview a local UI. Only fall back to forcing the boolean in the component if enabling the flag locally is not possible, and say so in your report.

For a stubbed mutation, resolve after a short delay so loading states are visible, and follow the component's existing mutation and loading-state pattern.

## Step 4: Cover the states worth seeing

A single happy-path shim is rarely enough for review. Where the change introduces them, make these reachable:

- Empty, single-item, and many-item variants.
- Loading and submitting states.
- Error and disabled states.
- Long strings, for truncation and wrapping.
- Light and dark mode, and the narrow breakpoint.

Prefer one shim helper with a small set of exported scenario builders over many scattered overrides. If the user needs to flip between scenarios, expose a constant at the top of the `temp-*` module that they can edit in one place.

## Step 5: Verify cheaply

Browser automation is slow. Verify with the fast checks first, and use the browser for a single confirmation, not a tour.

1. Follow Braintrust's development instructions to run the relevant typecheck and non-mutating lint checks.
2. Confirm the dev server is running using Braintrust's development instructions. Restart it if the shim's module or `.env*` changed and the change is not being served.
3. Load the route once in the browser and confirm the new UI is on screen. Allow for hydration: the first snapshot after navigation often still shows the server HTML, so re-snapshot before concluding the shim did not work.
4. Capture one screenshot of the primary state. Only take more when the user asked for screenshots, or when a state cannot be trusted without seeing it (layout, truncation, dark mode).

Do not click through every scenario, breakpoint, and theme. Leave the remaining states reachable via the scenario constant from Step 4 and tell the user how to reach them.

If the route is ambiguous, infer it from the changed files, links, and nearby pages. Use it and state the assumption when exactly one route is likely; ask a single clarifying question when several are.

## Step 6: Report and hand off

Report:

- What the branch changes, in one or two sentences, and where the evidence came from (PR, commits, diff).
- The gate you found and where it lives.
- Every file you added or touched for the shim, and exactly what each one fakes.
- The route(s) to view it, and which states are reachable.
- The removal command, e.g. `rm utils/temp-<topic>.ts` plus the call sites to revert, and any `.env*` or local setting the user must undo by hand. Step 7 has the full teardown procedure.

## Step 7: Tear down

Teardown is a first-class task, not an afterthought. Run it when the user asks to remove, revert, clean up, or "undo" the shim, and when a shim from an earlier session is in the way — a stale `temp-*` module that no longer typechecks blocks typechecking for every later task.

Find every trace before deleting anything. A shim is never just its module:

```bash
ls utils/temp-*.ts
grep -rn "temp-" --include="*.ts" --include="*.tsx" pages components hooks utils
git status --short
grep -rn "MOCK\|_MOCK_MODE" .env.local
```

Archive before removing anything, so the next session restores in seconds instead of rebuilding (Step 0):

```bash
mkdir -p .agents/shims/<topic>
cp utils/temp-<topic>.ts .agents/shims/<topic>/
git diff -- <call-site files> > .agents/shims/<topic>/wiring.patch
```

For call-site files that mix shim and real changes, edit the patch down to the shim hunks. Write `NOTES.md` alongside them covering the route to view, the scenario switch, and any flag or environment prerequisites, then overwrite any older archive for the same topic. Skip archiving only when the user says the shim is dead for good, or it was broken beyond reuse.

Then remove, in this order:

1. Revert the call sites first, while the module still exists — `git checkout <file>` for files whose only changes were shim call sites, or hand-edit the specific lines for files that also carry real work.
2. Restore anything the shim borrowed from checked-in code: imports it dropped to stay lint-clean, delegating lines added to real mock helpers, props threaded through only for the shim.
3. Delete the `temp-*` module last, once nothing imports it.
4. Undo local environment changes the shim needed — `.env*` lines, enabled feature flags, toggled database settings — and restart the dev server if any of them changed.

Verify the teardown, do not assume it:

- `grep -rn "temp-" pages components hooks utils` returns nothing.
- The relevant typecheck and non-mutating lint checks from Braintrust's development instructions pass.
- The relevant tests from Braintrust's development instructions pass, at least those touching the shimmed page.
- `git status` shows only the changes the user meant to keep.

Report what you removed, what you deliberately kept (real feature edits, test updates that belong to the feature), and any local environment change the user still needs to undo by hand.

## Rules

- Shims are client-side and local only. Never change server behavior, migrations, or checked-in seed data to fake a UI state.
- Never commit a shim as part of the feature. If the user asks to commit work in progress, keep the shim in its own commit and say it must be dropped before merge.
- Never fabricate data that could be mistaken for real customer records — no real organization names, emails, or billing details.
- Do not weaken types, silence lint rules, or add `eslint-disable` to make a shim compile.
- Do not modify tests to accommodate a shim. If a shim would break a test, guard the shim instead — e.g. return early unless `process.env.NODE_ENV === 'development'` — so the suite keeps exercising the real code path.
- If the change genuinely cannot be shown client-side (it depends on real backend computation), say so plainly, describe what the backend would need to return, and shim the closest reviewable approximation instead of pretending it works.
