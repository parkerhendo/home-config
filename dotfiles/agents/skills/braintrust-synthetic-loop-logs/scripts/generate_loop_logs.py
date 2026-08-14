#!/usr/bin/env python3
"""Generate Braintrust project log NDJSON with root traces and fake LLM children."""

import argparse
import json
import random
import re
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_PAGES = [
    "logs",
    "experiments",
    "playground",
    "prompts",
    "datasets",
    "functions",
    "scorers",
    "evaluations",
    "observability",
    "members",
    "configuration",
    "traces",
    "deployments",
    "api_keys",
    "webhooks",
    "billing",
    "realtime",
    "charts",
    "annotations",
    "queues",
]

PERSONAS = [
    "engineer",
    "sre",
    "pm",
    "researcher",
    "security",
    "support",
    "solutions",
    "data_scientist",
    "evals_owner",
]

MODELS = ["gpt-5-mini", "gpt-5-nano", "claude-sonnet-4.5", "gemini-2.5-pro", "o4-mini"]
PROVIDERS = ["openai", "braintrust-proxy", "anthropic", "google"]

REQUEST_PATTERNS = [
    ("latency_triage", "Investigate why the selected run was slow and identify whether delay came from context assembly, model latency, or answer formatting."),
    ("missing_output", "Explain why the selected root span has no final output even though child LLM calls appear successful."),
    ("json_repair", "Repair a malformed assistant JSON response and describe the exact child span that introduced the invalid field."),
    ("prompt_regression", "Compare the current prompt revision with the previous revision and explain why the assistant started citing stale span ids."),
    ("eval_comparison", "Compare two experiment runs and explain why the newer run improved latency but reduced answer grounding."),
    ("golden_set", "Select examples for a golden set that cover missing output, bad filters, provider timeouts, and wrong selected spans."),
    ("trace_repro", "Turn the selected trace view into a compact reproduction prompt with failing input, metadata, and relevant child LLM outputs."),
    ("cost_spike", "Find the child calls responsible for a cost spike and propose a narrower retrieval budget."),
    ("cache_analysis", "Determine whether cache misses or a larger prompt caused the token increase in the selected run."),
    ("tool_argument_debug", "Inspect model-generated tool arguments and explain why the filter missed the expected child spans."),
    ("answer_contract", "Update the answer contract so the assistant returns a concise summary plus evidence without inventing hidden fields."),
    ("context_packing", "Summarize which context packets were included, which were dropped, and whether the answer still had enough evidence."),
    ("release_check", "Prepare a release-readiness note for a prompt change using only selected trace evidence."),
    ("support_handoff", "Create a support handoff that maps the customer question to root span, child spans, and a recommended next action."),
    ("security_review", "Review a trace for accidental exposure of sensitive identifiers and suggest a safer redaction pattern."),
    ("filter_builder", "Build a Braintrust log filter for root spans with high duration, empty output, and LLM children on the selected page."),
    ("chart_discrepancy", "Explain why the chart count disagrees with the visible trace table after filters were applied."),
    ("annotation_queue", "Pick the most useful traces for human review and justify each choice with child model evidence."),
    ("webhook_debug", "Diagnose why a webhook replay selected the wrong span and produce a minimal payload for reproduction."),
    ("model_fallback", "Identify where the model fallback happened and whether the fallback response changed the final answer shape."),
    ("rbac_explanation", "Explain why the user can see the root span but not a linked project row, using only visible fields."),
    ("btql_debug", "Rewrite a BTQL filter so it targets direct LLM children without excluding the root task span."),
]

STAGE_SPECS = [
    ("intent", "You classify the user request into page intent and decide whether trace context is needed. Return compact JSON."),
    ("planner", "You are Loop's planning model. Decide which Braintrust data to inspect and whether a tool call is needed."),
    ("query", "You translate user requests into Braintrust log filters. Prefer precise root span and span type filters."),
    ("context_pack", "You compress selected trace evidence into a compact context packet for the final answer."),
    ("answer", "You are Loop. Answer with concise debugging guidance grounded in the selected trace context."),
    ("self_check", "You verify that the answer cites only visible fields and does not invent hidden data."),
    ("rewrite", "You rewrite the answer for a user-facing support handoff while preserving evidence."),
]

FIELDS = [
    "root_span_id",
    "span_id",
    "input",
    "output",
    "metrics.duration",
    "metrics.prompt_tokens",
    "metrics.completion_tokens",
    "metadata.page",
    "metadata.stage",
    "span_attributes.type",
]

EVIDENCE_TEMPLATES = [
    "The user is viewing a Braintrust project with the logs table filtered to root spans. The selected trace has nested LLM spans, mixed JSON and natural-language outputs, and a long answer payload. Use field `{field}` when relevant.",
    "Several sibling spans share the same root but represent different LLM stages: intent classification, planning, query construction, context packing, final answer, and self-check. Use field `{field}` when relevant.",
    "The pasted conversation includes a Slack thread, a prompt diff, a dataset row preview, and a partial trace URL. Some identifiers are redacted but span ids remain visible. Use field `{field}` when relevant.",
    "The visible side panel includes duration, token counts, output JSON, request metadata, and previous assistant turns. Use field `{field}` when relevant.",
    "The project contains mixed production and synthetic traces. The current task is to inspect evidence without modifying data or inferring fields that are not present. Use field `{field}` when relevant.",
    "The user is comparing model responses across revisions. One response includes the right root span but wrong child span; another cites a stale experiment id. Use field `{field}` when relevant.",
    "The selected trace includes provider metadata, cache counters, time-to-first-token, and a final answer that may be null on the root span. Use field `{field}` when relevant.",
    "The table is sorted by duration but the user clicked a child span in the side panel, so the answer must distinguish row id, span id, and root span id. Use field `{field}` when relevant.",
]

TURN_SNIPPETS = [
    "The user has a side panel open with span details, including duration, prompt tokens, output JSON, request metadata, and previous assistant turns.",
    "A sibling child call produced a valid-looking filter, but it used the selected row id instead of the actual span id.",
    "The assistant should prefer exact root span, span id, metadata page, span type, and metrics fields when forming filters or summaries.",
    "The user pasted a prompt diff and wants evidence from the trace rather than a general explanation.",
    "Several model calls succeeded, but the root output is missing because the last merge step returned an empty value.",
    "The selected run has a high token count because the context packet repeated previous turns and included a large table preview.",
    "The current view is filtered to a specific page, but the user wants direct children under the selected root span only.",
    "The final answer should include a concise recommendation, evidence rows, and one safe next action.",
    "The user cares about whether the model output was grounded in visible trace evidence, not whether the product behavior was correct.",
    "A provider retry changed the answer style but did not change the selected root span.",
]

ARTIFACTS = [
    "Prompt diff:\n- Always cite the selected span.\n+ Cite the selected root and direct LLM child spans only when present.\n+ If output is null, say so explicitly.",
    "Support note:\nCustomer says the logs table shows three calls, but the side panel shows five. They need a reproduction prompt for the prompt owner.",
    "Dataset preview:\n[{\"input\":\"summarize trace latency\",\"expected\":\"identify slow child call\"},{\"input\":\"repair json\",\"expected\":\"valid compact object\"}]",
    "Table columns visible:\nroot_span_id | span_id | span_attributes.type | metadata.stage | metrics.duration | metrics.prompt_tokens | output",
    "Provider diagnostics:\nretry_count=1; cache_read_tokens varied; completion reasoning tokens sometimes present; final merge may omit output.",
    "Runbook excerpt:\nStart with the root row, inspect direct children, compare planner output to query output, then inspect answer output.",
    "User constraints:\nDo not mutate project data. Do not invent unavailable columns. Keep the answer short enough for Slack.",
]

DISALLOWED_KEYS = {"facets", "facet", "topics", "topic", "classifications"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate synthetic Loop-like Braintrust project logs.")
    parser.add_argument("--project-id", required=True, help="Destination Braintrust project ID.")
    parser.add_argument("--project-name", default="Loop [cloned]", help="Project display name used in generated inputs.")
    parser.add_argument("--use-case", required=True, help="The product scenario the generated logs should represent.")
    parser.add_argument("--trace-count", type=int, default=240, help="Number of root traces to generate.")
    parser.add_argument("--min-children", type=int, default=3, help="Minimum direct LLM children per trace.")
    parser.add_argument("--max-children", type=int, default=7, help="Maximum direct LLM children per trace.")
    parser.add_argument("--pages", default=",".join(DEFAULT_PAGES), help="Comma-separated page names to vary across traces.")
    parser.add_argument("--batch", default=None, help="Batch label stored in metadata.sample_batch.")
    parser.add_argument("--created-from", default=None, help="Start of timestamp range (ISO 8601 or relative like '-48h'). Default: 48 hours ago.")
    parser.add_argument("--created-to", default=None, help="End of timestamp range (ISO 8601 or relative like '-1h'). Default: now.")
    parser.add_argument("--seed", type=int, default=64193, help="Random seed for deterministic output.")
    parser.add_argument("--output", required=True, help="Output JSONL path.")
    return parser.parse_args()


def stable_uuid(batch: str, *parts: object) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "braintrust-loop-sample/" + batch + "/" + "/".join(map(str, parts))))


def iso(timestamp: float) -> str:
    return datetime.fromtimestamp(timestamp, tz=timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def parse_time_spec(spec: str | None, now: float) -> float:
    """Parse a time spec: 'now', ISO 8601 datetime, or relative time like '-48h', '-30m', etc."""
    if spec is None or spec.lower() == "now":
        return now
    spec = spec.strip()
    if spec.startswith("-") or spec.startswith("+"):
        # Relative time
        match = re.match(r"([+-])(\d+)([smhd])", spec)
        if not match:
            raise ValueError(f"Invalid relative time format: {spec}. Use format like '-48h', '-30m', '+2d'.")
        sign, amount, unit = match.groups()
        amount = int(amount)
        multipliers = {"s": 1, "m": 60, "h": 3600, "d": 86400}
        if unit not in multipliers:
            raise ValueError(f"Unknown time unit: {unit}. Use s/m/h/d.")
        delta = amount * multipliers[unit]
        return now + (delta if sign == "+" else -delta)
    else:
        # ISO 8601 datetime
        try:
            dt = datetime.fromisoformat(spec.replace("Z", "+00:00"))
            return dt.timestamp()
        except ValueError as e:
            raise ValueError(f"Invalid datetime format: {spec}. Use ISO 8601 (e.g., '2026-06-17T22:00:00Z') or relative time (e.g., '-48h').") from e


def tokens_for(value: object, rng: random.Random) -> int:
    return max(120, min(9000, len(json.dumps(value, sort_keys=True)) // 4 + rng.randint(20, 180)))


def metrics(start: float, duration: float, prompt_tokens: int, completion_tokens: int, reasoning: int, cached: int, rng: random.Random) -> dict:
    end = start + duration
    return {
        "start": start,
        "end": end,
        "duration": duration,
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "completion_reasoning_tokens": reasoning,
        "prompt_cached_tokens": cached,
        "total_tokens": prompt_tokens + completion_tokens,
        "estimated_cost": round(prompt_tokens * 0.00000015 + completion_tokens * 0.0000006 + reasoning * 0.0000003, 7),
        "time_to_first_token": round(rng.uniform(0.12, 1.7), 6),
    }


def make_context(batch: str, project_name: str, rng: random.Random, i: int, page: str, request_kind: str, root_id: str, child_count: int, use_case: str) -> dict:
    selected_span = "span_" + stable_uuid(batch, i, "selected").replace("-", "")[:16]
    prior_turns = []
    for turn in range(1, rng.randint(6, 14)):
        prior_turns.append({
            "turn": turn,
            "role": "user" if turn % 2 else "assistant",
            "content": f"{rng.choice(TURN_SNIPPETS)} Use case={use_case}. Requested page={page}, request_kind={request_kind}, root_span_id={root_id}, selected_span={selected_span}. Observed child_count={child_count}, row_offset={1000 + i * 7 + turn}.",
        })
    visible_children = []
    for c in range(child_count):
        stage = STAGE_SPECS[min(c, len(STAGE_SPECS) - 1)][0]
        visible_children.append({
            "name": "Chat Completion",
            "type": "llm",
            "stage": stage,
            "model": rng.choice(MODELS),
            "duration": round(rng.uniform(1.3, 12.8), 3),
            "preview": rng.choice(TURN_SNIPPETS),
        })
    return {
        "active_project": project_name,
        "active_page": page,
        "use_case": use_case,
        "root_span_id": root_id,
        "selected_span_id": selected_span,
        "visible_columns": ["root_span_id", "span_id", "span_attributes.type", "metadata.page", "metadata.stage", "metrics.duration", "metrics.prompt_tokens", "metrics.completion_tokens", "input", "output"],
        "prior_turns": prior_turns,
        "visible_children": visible_children,
        "pasted_artifacts": rng.sample(ARTIFACTS, k=rng.randint(2, 4)),
        "constraints": [
            "Ground every claim in visible trace fields.",
            "If a value is missing, say it is missing rather than inferring it.",
            "Return a concrete next action suitable for a prompt owner.",
        ],
    }


def make_root_input(batch: str, project_name: str, rng: random.Random, i: int, page: str, request_kind: str, task: str, root_id: str, child_count: int, use_case: str) -> str:
    context = make_context(batch, project_name, rng, i, page, request_kind, root_id, child_count, use_case)
    evidence_lines = []
    for j in range(rng.randint(7, 13)):
        evidence_lines.append(f"- Evidence {j + 1}: " + rng.choice(EVIDENCE_TEMPLATES).format(field=rng.choice(FIELDS)))
    intro = rng.choice([
        f"I am on the {page} page. {task}",
        f"Can you inspect this Loop trace for {use_case} and help with: {task}",
        f"Here is a large selected trace context from {project_name}. {task}",
        f"Use the visible spans in the {page} view to answer this support question for {use_case}: {task}",
    ])
    return (
        f"{intro}\n\nUse case represented by these logs: {use_case}.\n\n"
        "The selected trace is large, so narrow the evidence before answering.\n"
        + "\n".join(evidence_lines)
        + "\n\nRaw selected context:\n"
        + json.dumps(context, separators=(",", ":"))
        + "\n\nAdditional pasted material:\n"
        + "\n\n".join(rng.sample(ARTIFACTS, k=rng.randint(1, 3)))
    )


def stage_output(batch: str, rng: random.Random, i: int, stage: str, page: str, request_kind: str, child_count: int, root_id: str, use_case: str) -> list[dict]:
    if stage == "intent":
        return [{"role": "assistant", "content": json.dumps({"request_kind": request_kind, "page": page, "use_case": use_case, "needs_trace_context": True, "expected_child_spans": child_count})}]
    if stage == "planner":
        args = {"project": "Loop [cloned]", "page": page, "root_span_id": root_id, "root_filter": "span_attributes.type = 'task'", "include_child_spans": True, "request_kind": request_kind, "limit": rng.choice([25, 50, 75, 100])}
        return [{"role": "assistant", "content": "I will inspect the root row, direct LLM children, and final answer evidence before proposing a change.", "tool_calls": [{"id": "call_" + stable_uuid(batch, i, stage).replace("-", "")[:10], "type": "function", "function": {"name": "bt_view_trace", "arguments": json.dumps(args)}}]}]
    if stage == "query":
        return [{"role": "assistant", "content": json.dumps({"filter": f"root_span_id = '{root_id}' AND (span_attributes.type = 'task' OR span_attributes.type = 'llm')", "sort": "metrics.duration DESC", "fields": ["root_span_id", "span_id", "input", "output", "metrics", "metadata.stage", "span_attributes.type"], "notes": "Use the root row for the user request and direct LLM children for model behavior.", "candidate_issue": rng.choice(["missing root output", "wrong selected span", "large context packet", "provider retry", "stale prompt revision"])})}]
    if stage == "context_pack":
        bullets = [f"root={root_id}", f"page={page}", f"use_case={use_case}", f"request_kind={request_kind}", f"direct_llm_children={child_count}", f"observed_issue={rng.choice(['empty root output', 'slow final answer', 'filter too broad', 'cache miss', 'tool argument mismatch'])}"]
        return [{"role": "assistant", "content": "Context packet:\n" + "\n".join(f"- {item}" for item in bullets)}]
    if stage == "answer":
        return [{"role": "assistant", "content": f"For sample {i}, this {use_case} trace is about {request_kind.replace('_', ' ')} on the {page} page. Inspect the root span first, then compare direct LLM children by duration and token count. The strongest evidence is the planner output, the query-stage filter, and the answer-stage response. Recommended next step: open the slowest child span and verify its input contains the selected context the user referenced."}]
    if stage == "self_check":
        return [{"role": "assistant", "content": json.dumps({"grounded": True, "uses_visible_fields_only": True, "missing_values_called_out": rng.choice([True, False]), "needs_follow_up": rng.choice(["open slow child", "compare prompt revision", "check root output", "reduce context budget"])})}]
    return [{"role": "assistant", "content": f"Support-ready rewrite: The selected {page} trace has {child_count} direct LLM child calls for {use_case}. Start from root_span_id {root_id}, inspect child stages in order, and attach the answer-stage output to the handoff."}]


def stage_input(project_name: str, rng: random.Random, stage: str, system_prompt: str, root_input: str, task: str, previous_outputs: list[list[dict]], page: str, request_kind: str, root_id: str, use_case: str) -> list[dict]:
    messages = [{"role": "system", "content": system_prompt}]
    if stage == "intent":
        messages.append({"role": "user", "content": root_input})
        return messages
    messages.append({"role": "user", "content": task})
    for prev in previous_outputs[-2:]:
        messages.append({"role": "assistant", "content": prev[0]["content"]})
    packet = {"selected_project": project_name, "selected_page": page, "use_case": use_case, "request_kind": request_kind, "root_span_id": root_id, "visible_fields": ["root_span_id", "span_id", "input", "output", "metrics", "metadata", "span_attributes"], "row_budget": rng.choice([25, 50, 100, 200]), "instruction": "Use exact span evidence and avoid inventing hidden data.", "recent_user_notes": rng.sample(TURN_SNIPPETS, k=3), "artifact_excerpt": rng.choice(ARTIFACTS)}
    if stage in {"answer", "self_check", "rewrite"}:
        messages.append({"role": "user", "content": root_input})
    messages.append({"role": "user", "content": json.dumps(packet)})
    return messages


def validate_no_disallowed_keys(value: object, path: str = "") -> list[str]:
    found = []
    if isinstance(value, dict):
        for key, nested in value.items():
            if key.lower() in DISALLOWED_KEYS:
                found.append(path + key)
            found.extend(validate_no_disallowed_keys(nested, path + key + "."))
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            found.extend(validate_no_disallowed_keys(nested, path + str(index) + "."))
    return found


def generate(args: argparse.Namespace) -> list[dict]:
    rng = random.Random(args.seed)
    batch = args.batch or "loop-varied-llm-samples-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%MZ") + "-no-facets"
    pages = [page.strip() for page in args.pages.split(",") if page.strip()]
    if not pages:
        raise ValueError("--pages must include at least one page")
    if args.trace_count <= 0:
        raise ValueError("--trace-count must be positive")
    if args.min_children < 1 or args.max_children < args.min_children:
        raise ValueError("child span bounds are invalid")

    rows = []
    now = time.time()
    # Parse timestamp range
    range_end = parse_time_spec(args.created_to, now)
    range_start = parse_time_spec(args.created_from, now - 48 * 3600)  # Default: 48 hours ago
    if range_start >= range_end:
        raise ValueError(f"Invalid timestamp range: --created-from ({range_start}) must be before --created-to ({range_end})")
    
    for i in range(args.trace_count):
        page = pages[i % len(pages)]
        request_kind, base_task = REQUEST_PATTERNS[(i * 7 + rng.randint(0, len(REQUEST_PATTERNS) - 1)) % len(REQUEST_PATTERNS)]
        task = f"{base_task} Frame the answer around this use case: {args.use_case}."
        persona = PERSONAS[(i * 5 + rng.randint(0, len(PERSONAS) - 1)) % len(PERSONAS)]
        child_count = rng.randint(args.min_children, args.max_children)
        root_id = stable_uuid(batch, i, "root")
        # Distribute trace start times evenly across the range, with jitter
        trace_position = i / max(1, args.trace_count - 1) if args.trace_count > 1 else 0.5
        trace_start = range_start + trace_position * (range_end - range_start) + rng.uniform(-300, 300)  # ±5 min jitter
        trace_start = max(range_start, min(range_end, trace_start))  # Clamp to range
        root_input = make_root_input(batch, args.project_name, rng, i, page, request_kind, task, root_id, child_count, args.use_case)
        stage_rows = []
        previous_outputs = []
        current_start = trace_start + rng.uniform(0.15, 1.2)
        total_prompt = total_completion = total_reasoning = total_cached = 0
        total_llm_duration = 0.0
        for c in range(child_count):
            stage, system_prompt = STAGE_SPECS[c]
            messages = stage_input(args.project_name, rng, stage, system_prompt, root_input, task, previous_outputs, page, request_kind, root_id, args.use_case)
            output = stage_output(batch, rng, i, stage, page, request_kind, child_count, root_id, args.use_case)
            prompt_tokens = tokens_for(messages, rng)
            completion_tokens = max(40, min(1200, len(json.dumps(output)) // 4 + rng.randint(20, 180)))
            reasoning = rng.choice([0, 0, 0, rng.randint(64, 900)])
            cached = rng.choice([0, 0, rng.randint(128, min(prompt_tokens, 3000))])
            duration = round(rng.uniform(1.4, 9.5) + prompt_tokens / rng.uniform(1300, 2600), 6)
            child_metrics = metrics(current_start, duration, prompt_tokens, completion_tokens, reasoning, cached, rng)
            span_id = stable_uuid(batch, i, stage)
            stage_rows.append({
                "id": stable_uuid(batch, i, stage, "row"),
                "input": messages,
                "output": output,
                "metadata": {"synthetic": True, "source": "bt-cli-generated-varied-test-data", "sample_batch": batch, "use_case": args.use_case, "page": page, "request_kind": request_kind, "stage": stage, "model": MODELS[(i + c + rng.randint(0, len(MODELS) - 1)) % len(MODELS)], "provider": PROVIDERS[(i + c) % len(PROVIDERS)], "request_id": "req_" + stable_uuid(batch, i, stage, "request").replace("-", "")[:18], "temperature": rng.choice([0, 0.1, 0.2, 0.4, 0.7])},
                "metrics": child_metrics,
                "scores": {},
                "created": iso(current_start),
                "span_id": span_id,
                "root_span_id": root_id,
                "span_parents": [root_id],
                "span_attributes": {"name": "Chat Completion", "type": "llm"},
                "is_root": False,
                "log_id": "g",
            })
            previous_outputs.append(output)
            total_prompt += prompt_tokens
            total_completion += completion_tokens
            total_reasoning += reasoning
            total_cached += cached
            total_llm_duration += duration
            current_start += duration + rng.uniform(0.1, 0.8)

        root_duration = round((current_start - trace_start) + rng.uniform(0.2, 2.5), 6)
        root_output = None if rng.random() < 0.18 else {"answer": f"I found {child_count} fake LLM calls for this {args.use_case} Loop trace and the final call addresses {request_kind.replace('_', ' ')}.", "child_llm_spans": child_count, "recommended_next_step": rng.choice(["Compare planner output with final answer evidence before changing the prompt.", "Open the slowest child span and verify the selected context was included.", "Reduce the context row budget and rerun the prompt on this root span.", "Attach the query-stage filter and answer-stage output to the handoff."])}
        root_metrics = {**metrics(trace_start, root_duration, total_prompt, total_completion, total_reasoning, total_cached, rng), "llm_calls": child_count, "llm_duration": total_llm_duration, "llm_errors": 0, "errors": 0, "tool_calls": rng.choice([0, 0, 1]), "tool_errors": 0}
        rows.append({
            "id": root_id,
            "input": root_input,
            "output": root_output,
            "metadata": {"synthetic": True, "source": "bt-cli-generated-varied-test-data", "sample_batch": batch, "use_case": args.use_case, "page": page, "request_kind": request_kind, "persona": persona, "email": f"loop-test-{persona.replace('_', '-')}@example.test", "user_id": stable_uuid(batch, i, "user"), "project_id": args.project_id, "llm_child_spans": child_count},
            "metrics": root_metrics,
            "scores": {},
            "created": iso(trace_start),
            "span_id": root_id,
            "root_span_id": root_id,
            "span_parents": None,
            "span_attributes": {"name": "optimization", "type": "task"},
            "is_root": True,
            "log_id": "g",
        })
        rows.extend(stage_rows)
    return rows


def main() -> int:
    args = parse_args()
    rows = generate(args)
    bad_keys = []
    for row in rows:
        bad_keys.extend(validate_no_disallowed_keys(row))
    if bad_keys:
        print("Generated rows contain disallowed keys: " + ", ".join(sorted(set(bad_keys))[:20]), file=sys.stderr)
        return 2

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n")

    root_count = sum(1 for row in rows if row.get("is_root"))
    llm_count = sum(1 for row in rows if row.get("span_attributes", {}).get("type") == "llm")
    batch = rows[0]["metadata"]["sample_batch"] if rows else args.batch
    print(json.dumps({"batch": batch, "traces": root_count, "rows": len(rows), "child_llm_rows": llm_count, "output": str(output)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
