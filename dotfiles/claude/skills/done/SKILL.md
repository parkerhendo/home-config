---
name: done
description: This skill should be used at the end of a Claude Code session to capture a summary of everything discussed, key decisions made, open questions, and follow-ups into a persistent markdown file. Triggers on "/done" or when the user signals they're wrapping up a session.
---

# Done — Session Notes

Capture a session summary into a markdown file for future context. Output path: `~/src/braintrustdata/working-notes/`.

## Workflow

### 1. Gather context

Collect the following from the current conversation:

- **Git info**: Run `git rev-parse --show-toplevel` to get the repo name (basename of the path), `git branch --show-current` for branch, and use the current session ID from the environment variable `$CLAUDE_SESSION_ID` (first 8 chars).
- **Conversation content**: Review the full conversation to extract the sections below.

### 2. Write the session note

Create a markdown file at:

```
~/src/braintrustdata/working-notes/{repo}-{branch}--{session-id-short}.md
```

Example: `braintrust-new-custom-view-editor--a1b2c3d4.md`

Create the `working-notes` directory if it doesn't exist.

The file should contain these sections:

```markdown
# {repo} / {branch}

**Date**: {YYYY-MM-DD}
**Session**: {full session id}

## Summary

Brief 2-4 sentence overview of what was accomplished this session.

## Key decisions

- Decision 1: rationale
- Decision 2: rationale

## Changes made

- `path/to/file` — what changed and why
- `path/to/other` — what changed and why

## Open questions

- Unresolved question or uncertainty
- Thing that needs further investigation

## Follow-ups

- [ ] Next step or task to pick up
- [ ] Another follow-up item
```

### 3. Guidelines

- Keep the summary concise — this is a reference doc, not a transcript.
- For "Changes made", use `git diff --stat` against the base branch to identify files touched, then summarize the *why* not just the *what*.
- Omit any section that has no content (e.g., if there are no open questions, skip that section).
- If the session was purely exploratory (no code changes), omit "Changes made" and focus on "Summary" and "Key decisions".
- Use sentence case throughout.
