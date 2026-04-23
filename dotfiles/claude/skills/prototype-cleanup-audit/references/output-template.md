# Output Document Template

The cleanup guide should follow this structure. Each section uses a single level of `##` headings. Every section should be exhaustive — do not skip points for brevity. The user makes prioritization decisions.

---

## Current architecture

Describe the feature holistically in 2-3 sentences, then cover:

### New files

Table format: `| File | Purpose | Lines |`

For each file: one-sentence purpose, key responsibilities, notable patterns.

### Modified files

Table format: `| File | What changed |`

For each: concise description of what was added/modified and why.

### Unrelated changes on this branch

List files that changed but are not part of the feature. Recommend removing or landing separately.

### Data flow

ASCII diagram showing the component hierarchy, data fetching, event flow, and key connections. Use `→` for data direction. Example:

```
parent.tsx
  ├─ scans data for condition → derives featureId
  └─ <FeatureView featureId={...}>
       ├─ useDataHook(featureId)
       │   └─ fetch(url) → raw data
       ├─ <ChildA data={...}>
       │   └─ renders/transforms data
       └─ <ChildB syncRef={...}>
            └─ animation loop reads ref → updates DOM
```

### Key dependencies

List external packages, APIs, env vars. Note versions and whether they're runtime or type-only.

---

## What is necessary vs. what is cruft

### Necessary — core to the feature

Numbered list. For each item: file name, why it's necessary, what happens without it.

### Cruft / to remove

Numbered list. For each: what it is, why it's cruft, evidence (dead code, duplication, unused).

### Borderline — review and decide

Items that are useful but tangential. For each: what it is, the trade-off, and a recommendation.

---

## Simplification opportunities

Numbered subsections (### 1. Title). For each:
- What the current approach is
- What the simpler alternative would be
- Trade-offs and a recommendation
- Code snippets where helpful

Focus on:
- Flattening component hierarchies
- Removing duplication with existing features
- Simplifying data detection/extraction logic
- Reducing lifecycle management complexity
- Reusing existing codebase components

---

## High-level critiques and ideas

Numbered subsections (### 1. Title). Strategic issues that affect production readiness:
- Missing infrastructure or backend dependencies
- Authentication/authorization gaps
- Missing SDK-side instrumentation
- UX inconsistencies with existing features
- Feature flagging needs
- Fragile patterns (magic strings, string manipulation, manual type definitions)

For each: describe the issue, explain the impact, and suggest a path forward.

---

## Performance issues and optimizations

Numbered subsections (### 1. Title). For each:
- Priority tag: HIGH / MEDIUM / LOW
- What the issue is, with specific file and line references
- Why it's a problem (quantify when possible)
- Concrete fix with code snippet

Common categories to check:
- Layout thrashing in animation loops (reading DOM in rAF)
- Linear searches that could be binary/indexed
- Bundle size of new dependencies
- Unnecessary re-renders or re-creations
- Continuous loops that run when idle
- Missing data validation on external inputs
- Memory leaks in lifecycle management

---

## Patterns from the codebase to reuse

For each pattern found in the existing codebase:
- Name the pattern and where it's used
- Explain how it's relevant to the feature being audited
- Note specific files/components that could be reused or extended

Focus on:
- Similar feature patterns (how do other views/tabs work?)
- Data fetching patterns (React Query configuration, loading states)
- Component composition (panel layouts, dynamic imports)
- Feature flagging conventions
- Error handling patterns
- Animation/synchronization patterns

---

## Proposed cleanup checklist

Ordered list (blocking items first, nice-to-haves last). Each item is a single actionable sentence. Group loosely:
1. Production blockers (infra, auth, missing backends)
2. Branch hygiene (separate unrelated changes)
3. Feature flagging
4. Code quality (dead code, duplication, fragile patterns)
5. Performance fixes
6. UX improvements
7. Future considerations
