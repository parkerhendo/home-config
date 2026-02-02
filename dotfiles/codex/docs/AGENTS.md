Summary - Read architecture/style guides. Write/run tests. Check lint/types. Hardcore code review.

---

- For all implementations [not for research or questions] do all these steps -
  - Plan
    - Create a solid, high quality architecture plan.
    - Read the `repo-root/docs/overview.md` if it exists in the repo.
    - Ensure plan is in accordance with `~/.codex/docs/style-guide.md`
  - Implement
    - Ensure you write tests for whatever you implement. Focus on happy paths, common edge cases and core logic.
    - Write high quality code in accordance with the `~/.codex/docs/style-guide.md`.
  - Validate
    - Run linter
    - Run type checker
    - Run tests
  - Review and refactor - Use `~/.codex/prompts/final-code-review.md` to perform a final code review
    and refactor.
  - Update `repo-root/docs/overview.md` with new/changed/deleted features and
    new/changed/deleted architecture elements.
- Look at ~/.codex/docs/AGENTS-local.md for extra instructions.
