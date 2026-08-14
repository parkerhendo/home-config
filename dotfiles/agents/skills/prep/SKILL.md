---
name: prep
description: Prepare code for commit by running cleanup and review passes. Use after completing work to clean up AI slop, simplify code, remove unused exports, fix lint/type errors, and perform a final code review.
---

# Prep for Commit

Run a complete cleanup and review pipeline to prepare code changes for commit or push.

## Pipeline Steps

Execute the following skills in order, waiting for each to complete before starting the next:

### 1. Deslop

Invoke the `/deslop` skill to remove AI-generated code slop:
- Extra comments
- Defensive checks
- Type casts to any
- Inconsistent style

### 2. Simplify

Invoke the `/simplify` skill to refine code for clarity:
- Reduce unnecessary complexity
- Apply project coding standards
- Improve readability

### 3. Knip

Invoke the `/knip` skill to clean up dead code:
- Remove unused files
- Remove unused exports
- Remove unused dependencies

### 4. Lint & Type Check

Run lint and type checking for the project:
- Run the project's lint command and fix any errors
- Run the project's type check command and fix any type errors
- Re-run checks to verify all issues are resolved

### 5. Code Review

Invoke the `/code-review` skill for final quality check:
- Check for bugs and issues
- Verify adherence to project conventions
- Ensure code quality

## Execution

Run each step sequentially using the Skill tool. After each step completes, proceed to the next. If any step identifies issues that require user input, pause and ask before continuing.

At the end, provide a brief summary of what was cleaned up and any remaining concerns from the code review.
