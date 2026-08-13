---
name: install-anti-slop
description: Audit a TypeScript or JavaScript repository with anti-slop Oxlint rules without modifying it, or install and configure the plugin locally. Use whenever a user asks to run or add anti-slop lint rules, copy the anti-slop plugin, configure opinionated Oxlint rules, or migrate an existing local anti-slop setup.
---

# Run or install anti-slop

Use audit mode to report findings without changing the target repository. Install the bundled plugin only when the user asks to adopt the rules in the repository.

## Audit without repository changes

1. Read the repository's agent instructions and check its working-tree status so existing findings and unrelated changes can be reported accurately.
2. Run from the target repository:

   ```bash
   node <skill-directory>/scripts/audit.mjs [path ...]
   ```

   With no paths, the script audits the current directory. It copies the plugin and installs matching `oxlint` and `@oxlint/plugins` versions under `~/.cache/pi/anti-slop-audit/`, then runs every anti-slop rule from an isolated configuration. It does not write to the target repository or use its Oxlint configuration.
3. Re-run with `--refresh` when current package versions are required:

   ```bash
   node <skill-directory>/scripts/audit.mjs --refresh [path ...]
   ```

4. Report findings without fixing them unless the user separately asks for cleanup. Do not suppress or weaken rules to make the audit pass.

## Install into the repository

1. Inspect the repository before changing it:
   - Read its agent instructions.
   - Check `git status` and preserve unrelated changes.
   - Identify the package manager from `packageManager` and lockfiles.
   - Find Oxlint configuration (`oxlint.config.*`, `.oxlintrc*`, or a Vite+ config).
   - Check whether anti-slop files or rules already exist. Do not overwrite them without reviewing the diff.

2. Copy the bundled plugin from this skill. Run from the target repository:

   ```bash
   node <skill-directory>/scripts/install.mjs
   ```

   This creates `tools/oxlint/anti-slop/`. Pass another relative destination as the first argument when the repository has an established tooling layout. The script refuses to replace an existing destination; only use `--force` after backing up and reviewing existing files.

3. Install current compatible dependencies rather than trusting versions remembered by the agent:
   - Query `npm view oxlint version` and `npm view @oxlint/plugins version`.
   - Install the same current version of both packages with the repository's package manager.
   - `oxlint` is a development dependency. The copied source imports `@oxlint/plugins`, so install it as a development dependency for a local-only plugin.
   - Do not replace the package manager or rewrite unrelated dependency ranges.

4. Register the plugin and enable all rules. For `oxlint.config.ts` or `.oxlintrc.json`, add:

   ```ts
   jsPlugins: [
     { name: "anti-slop", specifier: "./tools/oxlint/anti-slop/index.ts" },
   ],
   ```

   For Vite+, add that same entry to `lint.jsPlugins`. Merge it with existing entries instead of replacing them.

   Enable these rules at `"error"`:

   ```json
   {
     "anti-slop/no-chained-type-assertions": "error",
     "anti-slop/no-conditional-empty-object-spread": "error",
     "anti-slop/no-known-value-widening": "error",
     "anti-slop/no-module-mocking": "error",
     "anti-slop/no-object-parameters": "error",
     "anti-slop/no-reflect-apply": "error",
     "anti-slop/no-reflect-get": "error",
     "anti-slop/no-runtime-typeof": "error",
     "anti-slop/no-shape-in-symbol-names": "error",
     "anti-slop/no-unknown-parameters": "error",
     "anti-slop/no-unknown-returns": "error",
     "anti-slop/no-unknown-type-aliases": "error",
     "anti-slop/no-unsafe-dictionary-type": "error",
     "anti-slop/no-widen-then-assert": "error",
     "anti-slop/require-safety-comment-for-type-assertion": "error"
   }
   ```

5. Run the repository's lint command and typecheck. If findings appear, report them and fix them only when the user asked for migration/cleanup. Do not suppress rules, weaken rule severity, add unsafe casts, or mechanically launder types to make lint pass.

6. Review the final diff and clearly report:
   - copied path,
   - dependency versions installed,
   - configuration changed,
   - checks run and any remaining findings.

## Migration guidance

When replacing an older local copy, compare its rules and diagnostics before overwriting. Keep project-specific rules in their own plugin; anti-slop is intentionally generic. Prefer inference, `as const`, `satisfies`, named owner contracts, and boundary parsing when resolving findings.
