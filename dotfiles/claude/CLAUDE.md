# Global Preferences

## Style

- Sentence case for all UI text
- Extremely concise responses; sacrifice grammar for brevity
- Long/detailed responses → output to markdown files

## Behavior

- Never run typecheck or lint commands; ask user to run
- Avoid `useEffect` as a fix; usually a hack
- Create learning opportunities for user to write code
- List unresolved questions at end of plans (edge cases, error handling, unclear requirements)

## Working Notes

Throughout each session, progressively maintain a notes file at `~/src/braintrustdata/working-notes/`. These notes are embedded and searched via qmd to drive planning across sessions.

### When to write
- At the start of meaningful work: capture the goal and initial context
- After each significant discovery, decision, or direction change
- When encountering open questions or blockers
- Don't wait until the end — write as you go

### File naming
- `{branch-or-task}--{short-date}.md` (e.g. `fix-auth-timeout--20260416.md`)
- If resuming work from a prior session's notes, append to the existing file

### Structure
Use `##` section headers as chunk boundaries (these become discrete embedding units):

```md
---
tags: [area, feature, type-of-work]
branch: the/branch-name
status: in-progress | complete | blocked
date: 2026-04-16
---

# {task/branch description}

## Context
What we're doing and why. Link to relevant PRs/issues.

## Discoveries
### {timestamp or short label}
What was found, where, and why it matters.

## Decisions
### {decision label}
What was decided and the reasoning. Include rejected alternatives.

## Open Questions
- Unresolved items, edge cases, unclear requirements

## Plan / Next Steps
- What remains; ordered if possible
```

- **tags**: short labels for the area/feature/work-type (e.g. `[btcli, auth, refactor]`)
- **branch**: git branch if applicable; omit if no branch yet
- **status**: update as work progresses; set to `complete` at session end if done
- **date**: date the file was created

### What to capture
- Architecture observations that aren't obvious from code
- Why a particular approach was chosen over alternatives
- Surprising behavior, gotchas, or implicit constraints
- Cross-cutting concerns that span multiple files/services
- Context that would help someone (or future Claude) pick up this work

### What NOT to capture
- Mechanical change lists (git log covers this)
- Boilerplate or obvious code patterns
- Anything already in CLAUDE.md or ARCHITECTURE.md

## Git

- Never say authored by Claude in commits/PRs
- Run typechecks only after significant refactoring
