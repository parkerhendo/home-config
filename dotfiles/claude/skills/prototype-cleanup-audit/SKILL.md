---
name: prototype-cleanup-audit
description: "This skill should be used when a user has a prototype or WIP feature branch and needs a comprehensive cleanup guide before shipping to production. It produces an exhaustive markdown document covering architecture, necessary vs. cruft code, simplification opportunities, performance issues, and a prioritized cleanup checklist. Triggers on requests like 'audit this prototype', 'help me clean up this branch', 'what needs to change before shipping this feature', or 'write a cleanup guide for this branch'."
---

# Prototype Cleanup Audit

## Overview

Produce an exhaustive markdown cleanup guide for a prototype/WIP feature branch. The guide orients someone (often future-self or a teammate) for the work of cleaning up and shipping the feature to production. The output is a document, not code changes — the user makes prioritization decisions based on the guide.

## When to use

- A feature branch has prototype/experimental code that needs cleanup before merging to main
- The user is unfamiliar with the feature area and needs orientation
- The user asks for an audit, cleanup guide, or shipping readiness assessment of a branch
- Before starting production cleanup work on a WIP branch

## Workflow

### Phase 1: Discovery

Run these investigation steps in parallel where possible to maximize efficiency.

#### 1.1 Identify all changes on the branch

```bash
git diff main...HEAD --stat
```

Separate the changes into categories: new files, modified files, and unrelated/tangential changes. Understanding the full scope upfront prevents surprises later.

#### 1.2 Read every new and modified file

Read each file changed on the branch in full. For large files (>1000 lines), read the diff instead:

```bash
git diff main...HEAD -- path/to/large-file.tsx
```

While reading, track:
- What each file does and why it exists
- Dependencies between files (imports, shared types, data flow)
- Dead code (exported but never imported, unused functions)
- Prototype artifacts (hardcoded values, TODO comments, commented-out code)

#### 1.3 Explore related codebase patterns

Use the Agent tool with `subagent_type: "Explore"` to investigate:
- **Similar features** — How do existing features with comparable UX patterns work? What components do they use? How are they integrated?
- **Data fetching patterns** — How do other features fetch, cache, and display data?
- **Component composition** — What layout patterns, panel systems, or view type mechanisms exist?
- **Feature flagging** — How are other features gated for rollout?

The goal: identify established patterns the feature should follow, and existing code it could reuse instead of duplicating.

#### 1.4 Analyze external dependencies

For any new packages added:
- Check bundle size impact (look at node_modules or lockfile)
- Verify dynamic import patterns for large libraries
- Check for version conflicts or duplicates in the lockfile
- Identify whether the dependency is runtime or type-only

For any external APIs or services:
- Check if the endpoint is configured for production (env vars, infrastructure)
- Check if authentication/authorization is implemented
- Check if there's a backend service or if it's a gap

#### 1.5 Analyze performance characteristics

Look for:
- Animation loops (rAF) — do they read DOM layout properties? Do they run when idle?
- Linear searches in hot paths — could they be binary search or indexed?
- Component re-renders — are expensive computations memoized? Are refs used for high-frequency updates?
- Memory lifecycle — are event listeners, observers, and timers cleaned up?
- Data validation — is external input validated before use?

### Phase 2: Analysis

Synthesize findings into the output document structure. The analysis should cover:

1. **Necessary vs. cruft** — For each file/function, determine: Is this core to the feature? Is it dead code? Is it a prototype artifact? Is it duplicating existing functionality?

2. **Simplification opportunities** — Where can the design be simplified? Can components be merged? Can existing codebase features be reused? Can detection/extraction logic be made more robust?

3. **Pattern alignment** — Where does the implementation deviate from established codebase patterns? Where should it follow existing conventions (feature flags, error handling, data fetching, layout)?

4. **Production blockers** — What's missing for production? Authentication? Backend services? Infrastructure config? Feature flags?

### Phase 3: Document generation

Read the output template at `references/output-template.md` for the document structure. Write the cleanup guide to a markdown file in the repo root (not in the source tree).

Key principles for the output:
- **Exhaustive, not prioritized** — Cover everything. The user decides what matters.
- **Specific, not vague** — Include file paths, line numbers, code snippets. "The detection logic is fragile" is useless; "line 2713 matches on `name === 'Replay'` which is a magic string" is actionable.
- **Opinionated but balanced** — Provide recommendations, but explain trade-offs so the user can disagree.
- **Ordered by priority in the checklist** — Production blockers first, nice-to-haves last.

### Output location

Write the document to a descriptive filename in the repo root:

```
{feature-name}-cleanup-guide.md
```

## UX principles to evaluate against

When the user provides UX principles for the feature, evaluate the implementation against each one and call out gaps in the "High-level critiques" section. Common principles to check:

- **Consistency with existing app patterns** — Does the feature follow the same layout, interaction, and visual patterns as similar features?
- **Progressive disclosure** — Is the feature hidden when not relevant (e.g., tab only appears when data exists)?
- **Error states** — Are loading, error, and empty states handled consistently with the rest of the app?
- **Accessibility** — Are interactive elements keyboard-navigable? Do they have appropriate ARIA labels?

## Research strategy

Effective audits require deep codebase exploration. Use subagents aggressively:

- Launch multiple `Explore` agents in parallel for independent research questions
- One agent per concern area: "How does feature X work?", "What are the performance characteristics of Y?", "Where is Z used?"
- Each agent should return concise findings — synthesize into the final document yourself

Avoid doing shallow exploration. The value of this skill is depth — reading every file, understanding every connection, checking every edge case. Surface-level audits that miss dead code, fragile patterns, or production blockers defeat the purpose.
