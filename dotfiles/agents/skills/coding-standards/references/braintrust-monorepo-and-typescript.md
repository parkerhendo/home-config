# Braintrust monorepo and TypeScript conventions

Use this reference only in the `braintrustdata/braintrust` monorepo. Read the root `AGENTS.md`, then the nearest nested `AGENTS.md`; those files and package configuration remain authoritative when this reference drifts.

Also read the path-specific Braintrust references when touching `app/`, `api-ts/`, or `local/js/`.

## Repository boundaries

Choose the existing owner before adding code:

- `app/` is the Next.js product application and control plane.
- `api-ts/` is the Express-based data plane API and supporting workers/runtimes.
- `local/js/` contains private workspace packages shared across those runtimes.
- `@braintrust/typespecs` owns established public API and object schemas.
- `@braintrust/local-core` owns small domain-neutral utilities that any local package may depend on.
- `@braintrust/local-api-schema` owns shared data-plane schemas.
- `@braintrust/local-app-schema` owns shared control-plane schemas.
- Other `@braintrust/local-*` packages own the capability named in their `package.json` description, such as query, trace, functions, auth, security, or optimization.

Keep feature-only behavior with its feature. Move behavior into `local/js/` only when it must run in more than one runtime or has a stable package-level owner. Do not create a generic shared package or helper file as a substitute for choosing an owner.

Before adding a generic type guard or collection/object helper, search `braintrust/util` and `@braintrust/local-core`. Extend the established owner rather than defining another `isObject`, `isRecord`, `isEmpty`, or similar helper inside a component or handler.

## TypeScript syntax

Braintrust's configured conventions override generic alternatives:

- Use double quotes and Prettier.
- Use ES module imports in TypeScript. Existing `require` calls at runtime-specific boundaries are not a template for new application code.
- Use inline type imports: `import { helper, type HelperOptions } from "..."`. Do not introduce a separate `import type` when the module also has value imports.
- Do not use `any`, non-null assertions, or type assertions. Parse, narrow, or change the type instead. Existing lint suppressions and `MISSING JUSTIFICATION` comments are legacy debt, not examples to copy.
- Use `const` unless reassignment is required.
- Prefix intentionally unused bindings with `_`.
- Include every React hook dependency; `useBtql` is covered by the same exhaustive-deps rule.
- Use `.ts` unless the file contains JSX; use `.tsx` when it does.

Do not introduce branded identifiers, `Result` wrappers, service interfaces, or classes solely to make surrounding Braintrust code conform to a generic pattern. Reuse the schema-derived ID types, error mechanism, and functional module style of the owning area unless the task is an explicit migration or the new abstraction removes real caller complexity.

## Imports and package APIs

- In `app/`, use the `#/` alias for imports that cross app subtrees. Relative imports are appropriate for neighboring files within one cohesive feature.
- Import workspace packages through an exported package entrypoint, such as `@braintrust/local-core` or the declared `@braintrust/local-optimization/tools` subpath. Do not reach through a package's undeclared source path.
- A `local/js/*/index.ts` barrel is an intentional package entrypoint. Internal files within the same package may import their direct owner.
- Add a new subpath export only when consumers need a genuinely separate public surface or runtime boundary.
- Avoid new exports unless production code needs them. When a private pure function must be reached by tests, prefer a clearly named testing-only alias such as `testingOnlyBuildX` or `XForTests` over pretending it is a production API.

## Comments and naming

Braintrust does not require blanket JSDoc for every export. This overrides the generic exported-symbol JSDoc rule in [`comments-and-jsdoc.md`](comments-and-jsdoc.md).

Do not add comments that restate the code. Add a comment when it preserves a non-obvious reason, compatibility constraint, security boundary, measured query-plan decision, operational invariant, or framework workaround. Required examples include explaining why `stopPropagation()` or `preventDefault()` is necessary.

Use searchable domain names and stable error text. UI copy uses sentence case.

## Dependencies and generated artifacts

- Use `pnpm`, never npm or yarn.
- Add dependencies in the owning workspace, not at the repository root. For the app, use `cd app && pnpm add <package>`.
- Use `workspace:*` for private workspace dependencies, following neighboring package manifests.
- Check whether the dependency or helper already exists before adding another library.
- Do not hand-edit generated bundles, declaration output, snapshots, schema artifacts, or Bazel materializations unless the governing generator explicitly requires it. Update the source and run the owning generator.

## Verification

Use the repository-owned commands rather than inventing equivalent tool invocations:

- `app/`: run `make app-verify FILES="<changed app files>"`; use the narrower `make app-verify-*` targets while iterating.
- `api-ts/`: run the package lint/typecheck scripts or their Bazel targets, and run `bazel test --config=release //api-ts:tests` when the full API test suite is warranted.
- `local/js/`: run the affected package's Vitest script with `pnpm --filter "<package-name>" test`; build affected package dependencies when the change crosses package boundaries.

Keep checks targeted during iteration, then run the complete check required by the nearest `AGENTS.md`. Do not start the app dev server or run a production app build when `app/AGENTS.md` says the user owns those processes.

## Canonical anchors

Inspect these before changing a convention:

- `AGENTS.md`
- `app/AGENTS.md`
- `eslint.config.cjs`
- `app/.oxlintrc.json`
- `app/tsconfig.json`, `api-ts/tsconfig.json`, `local/js/tsconfig.json`
- `pnpm-workspace.yaml`
- `local/js/*/package.json`
- `Makefile` and `scripts/app-verify.sh`
