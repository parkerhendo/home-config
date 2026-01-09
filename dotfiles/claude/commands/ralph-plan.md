ultrathink:

# Ralph Wiggum Planning

The Ralph Wiggum technique (from Geoffrey Huntley) runs Claude in a loop, implementing one item at a time from a plan. Each iteration gets a fresh context window but reads the same spec/plan, making it "deterministically bad in an undeterministic world." Key principles: one item per loop, specs drive everything, capture learnings for future iterations.

Plan a feature, then optionally start the Ralph loop.

## What to do

1. **Quick pre-read** (~5 files max): Read CLAUDE.md, explore relevant code
2. **Ask 1-2 questions** using `AskUserQuestion` if anything is unclear. Don't ask obvious things.
3. **Write the spec** to `.context/spec.md`:

   ```markdown
   # [Feature Name]

   ## Why We're Building This

   ## What We're Building

   ## Design Decisions

   ## Out of Scope

   ## Success Criteria
   ```

4. **Write the plan** to `.context/plan.md`:

   ```markdown
   # Plan

   - [ ] Item 1 (foundational first)
   - [ ] Item 2
   ```

5. **Show the plan** and ask if they want to start the loop: `./scripts/ralph.sh`. Never start without approval.

Keep plans proportional to complexity. Each item should be one iteration.

## Feature to plan

$ARGUMENTS
