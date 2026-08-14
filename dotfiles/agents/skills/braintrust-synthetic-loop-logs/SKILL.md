---
name: braintrust-synthetic-loop-logs
description: Generates and uploads Loop-like synthetic Braintrust project logs with root traces and multiple fake LLM child spans. Use when the user asks to seed Braintrust/Loop logs, generate 200-300 sample traces, clone the shape of Loop traces, or specify a use case for synthetic LLM trace data.
---

# Braintrust Synthetic Loop Logs

## Quick start

When the user asks for synthetic Loop-like logs, first ask for the represented use case if they did not provide one.

```bash
PROJECT_ID="<project-id>"
PROJECT_NAME="Loop [cloned]"
USE_CASE="<user-specified scenario>"
BATCH="loop-varied-llm-samples-$(date -u +%Y%m%dT%H%MZ)-no-facets"
OUT="/tmp/${BATCH}/part-000001.jsonl"

python "$HOME/.agents/skills/braintrust-synthetic-loop-logs/scripts/generate_loop_logs.py" \
  --project-id "$PROJECT_ID" \
  --project-name "$PROJECT_NAME" \
  --use-case "$USE_CASE" \
  --trace-count 240 \
  --batch "$BATCH" \
  --created-from "-48h" \
  --created-to "now" \
  --output "$OUT"

bt sync push "project_logs:${PROJECT_ID}" --in "$OUT" --fresh --json
```

## Workflow

1. Inspect the target project before generating anything.
   - Confirm auth/context: `bt status --json` and, if needed, `bt auth profiles --json`.
   - Find the project ID: `bt projects list --json`.
   - Inspect recent root logs: `bt view logs -p "<project>" --json --non-interactive --limit 10 --window 30d`.
   - Inspect at least one representative trace: `bt view trace --object-ref project_logs:<project-id> --trace-id <root-span-id> --json --non-interactive --preview-length 1000`.

2. Generate a fresh NDJSON file.
   - Default to 240 traces unless the user asks for another count; keep normal requests in the 200-300 range.
   - Pass the user's scenario through `--use-case`; it is included in root inputs, child inputs, and metadata.
   - Each trace has one root task span and 3-7 direct fake LLM child spans with chat-message inputs/outputs.
   - **Timestamp distribution** (control with `--created-from` and `--created-to`):
     - Default: 48 hours ago to now (if neither flag specified)
     - Supports relative time: `-48h`, `-24h`, `-30m`, `-7d` (offset from now)
     - Supports absolute time: ISO 8601 format like `2026-06-17T22:00:00Z`
     - Traces are distributed across the range with ±5 minute jitter for realism

3. Push the NDJSON with `bt sync push`.
   - Use the same auth flags/profile/org that worked during inspection, e.g. `--profile <profile> --prefer-profile -o <org>`.
   - Do not use `--traces` for the final push unless the user explicitly wants a partial upload.
   - It is okay to do a one-trace smoke push only if you use a throwaway batch or intentionally re-push the full file afterward.

4. Validate after upload.

```bash
bt sql --json "SELECT count(*) AS rows,
  sum(CASE WHEN is_root = true THEN 1 ELSE 0 END) AS roots,
  sum(CASE WHEN span_attributes.type = 'llm' THEN 1 ELSE 0 END) AS llm_children,
  count(facets) AS rows_with_facets,
  count(classifications) AS rows_with_classifications
FROM project_logs('<project-id>')
WHERE created >= '<yyyy-mm-ddT00:00:00Z>'
  AND metadata.sample_batch = '<batch>'"
```

Also spot-check with `bt view logs --filter "metadata.sample_batch = '<batch>'"` and `bt view trace` on one returned root span.

## Timestamp examples

```bash
# Last 48 hours (default if no flags specified)
--created-from "-48h" --created-to "now"

# Last 24 hours
--created-from "-24h"

# Last 7 days
--created-from "-7d"

# Specific ISO 8601 range
--created-from "2026-06-15T00:00:00Z" --created-to "2026-06-17T23:59:59Z"

# Mix relative and absolute
--created-from "-72h" --created-to "2026-06-17T22:00:00Z"

# Last hour
--created-from "-60m" --created-to "now"
```

## Guardrails

- **NEVER populate any topic-related data fields.** Do not fill in:
  - `facets` (Sentiment, Task, Issues, Topics, or any other facet names)
  - `classifications` (any classification labels, ids, or metadata)
  - `tags` (all tags must be omitted)
  - Any fields associated with topic modeling, clustering, or user-defined facet schemas
  - The generator refuses disallowed keys and omits all such fields entirely.
- Keep generated data obviously synthetic: fake emails, fake request IDs, fake user IDs, and `metadata.synthetic=true`.
- Preserve the Loop-like shape: root span name `optimization`/type `task`, children named `Chat Completion`/type `llm`, shared `root_span_id`, and direct `span_parents` pointing to the root.
- Use `bt` CLI for inspection and upload; avoid direct API calls unless the CLI cannot perform the task.
