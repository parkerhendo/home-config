# Braintrust schemas and local JavaScript packages

Use this reference when changing Zod schemas, shared contracts, or packages under `local/js/` in the Braintrust monorepo.

Also read [`braintrust-monorepo-and-typescript.md`](braintrust-monorepo-and-typescript.md), [`parsing-and-schemas.md`](parsing-and-schemas.md), and [`testing.md`](testing.md).

## Choose the contract owner

Use the narrowest established package that can own the contract:

- `@braintrust/typespecs`: established public API/object contracts shared broadly across the repository.
- `@braintrust/local-api-schema`: shared data-plane request, response, logical-schema, insertion, automation, and related validation.
- `@braintrust/local-app-schema`: shared control-plane endpoint, ACL, view, Brainstore-control, and configuration validation.
- `@braintrust/local-core`: small domain-neutral utilities and constants, not feature policy.
- Another `@braintrust/local-*` package when the schema belongs to that package's named capability.

A schema used by only one module stays with that module until cross-runtime reuse or package ownership is real. Do not move a schema into a generic package only to make it importable.

## Zod is the runtime contract

Use the repository's installed Zod version and derive TypeScript types with `z.infer`. Do not duplicate a Zod contract as a handwritten interface.

Compose from existing schemas when fields share the same meaning:

- reuse `.shape.field` for the exact field contract;
- use `.pick`, `.omit`, `.extend`, `.merge`, `.and`, arrays, and discriminated unions to express protocol variants;
- use transforms/defaults when normalization is part of the contract;
- use `z.unknown()` and narrow it rather than `z.any()`.

Name exported schemas after the contract they parse, such as `tokenBudgetConfigRowSchema` or `fetchTokenBudgetConfigsArgsSchema`, and derive the corresponding type next to the schema.

Parse all less-trusted boundaries, including:

- route input after the auth/request envelope is decoded;
- external provider responses;
- rows returned from Postgres, JSON/JSONB, caches, and object storage;
- data read by a newer control plane from an older data plane;
- route output before serialization when the route harness supports an output schema.

Use `parse` when invalid data should fail the current operation. Use `safeParse` when the caller has an explicit fallback, skip, or error-classification branch. Do not use `safeParse(...).data` to silently turn malformed required data into absence.

## Backward compatibility

Shared schemas are compatibility surfaces. Do not make a backward-incompatible schema change:

- do not add a new required field to an existing request or response;
- do not change optional/nullish fields to required;
- do not narrow an enum, literal union, or accepted legacy representation;
- do not remove a deprecated field until every supported control plane, data plane, SDK, and persisted representation has moved off it;
- do not change a default or transform without checking old serialized values and mixed-version deployments.

When the app consumes responses from potentially older data planes, new response fields are normally optional or nullish. `local/js/api-schema/endpoint_schemas.ts` explicitly uses this pattern for `brainstoreSegmentInfoSchema`. Add a default only when missing data has a real, stable semantic meaning; otherwise preserve absence.

Test both sides of a compatibility change: the new representation and representative legacy/missing-field input. A deprecation test should prove the old shape continues to parse until removal is intentionally coordinated.

## Endpoint schema structure

For a shared control-plane endpoint, follow `local/js/app-schema/endpoints/`:

- define `inputSchema` and `outputSchema` in the endpoint's typespec file;
- derive any exported request/response types from those schemas;
- register the pair in `endpointSchemas` when the generic endpoint mechanism consumes it.

For a shared data-plane contract, export it through `local/js/api-schema/index.ts` or an intentionally declared package subpath. Keep protocol field names, including snake_case, in the schema; translate to local camelCase names only after parsing when that improves application code.

Validate output as well as input at API boundaries. This catches invalid database/provider data before it becomes a mixed-version client contract.

## Package boundaries and dependencies

Each `local/js/*` directory is a private pnpm workspace and Bazel subpackage. Its `package.json` description is the short ownership statement.

- Depend on sibling workspace packages with `workspace:*`.
- Keep dependency direction narrow. In particular, `local-core` must remain small and domain-neutral because any local package can depend on it.
- Use the package root export for its primary API. Add a declared subpath, as `@braintrust/local-optimization/tools` does, only for a distinct supported surface.
- Update the owning `index.ts`, package export map, and build configuration together when a new public entrypoint is genuinely required.
- Do not import from another package's unexported source files.
- Keep Node-only, browser-only, and shared code separated when a package is consumed by both `app/` and `api-ts/`.

Do not create fallback or placeholder domain data when a dependency is unavailable. Fail with the actual parse, configuration, or provider error; fake values can contaminate logs, evals, and persisted state.

## Tests

- Co-locate Vitest tests beside the schema or package module.
- Add parse-success and parse-failure cases for meaningful refinements and discriminated variants.
- For compatibility changes, include fixtures for missing, null, deprecated, and current representations as applicable.
- Test transforms/defaults by asserting the normalized output, not only `success === true`.
- Test package behavior through the exported package surface when the export contract is what consumers depend on.

Run the affected package test with `pnpm --filter "<package-name>" test`. Build affected upstream dependencies when changing exports or declarations.

## Canonical anchors

- `local/js/*/package.json`
- `local/js/*/index.ts`
- `local/js/core/package.json`
- `local/js/api-schema/package.json` and `local/js/api-schema/endpoint_schemas.ts`
- `local/js/app-schema/package.json` and `local/js/app-schema/endpoints/schemas.ts`
- `local/js/app-schema/token-budget.ts`
- `local/js/optimization/package.json` for intentional subpath exports
- `local/js/tsconfig.json` and `local/js/vitest.config.js`
