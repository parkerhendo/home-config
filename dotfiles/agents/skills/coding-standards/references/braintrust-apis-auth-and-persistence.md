# Braintrust APIs, authorization, and persistence

Use this reference for backend TypeScript in `app/`, `api-ts/`, and shared persistence/auth code. Read the root and nearest `AGENTS.md` first.

Also read [`braintrust-monorepo-and-typescript.md`](braintrust-monorepo-and-typescript.md), [`braintrust-schemas-and-local-packages.md`](braintrust-schemas-and-local-packages.md), [`persistence.md`](persistence.md), and [`sensitive-data-and-observability.md`](sensitive-data-and-observability.md).

## Keep the two planes distinct

- The `app/` control plane owns organizations, projects, users, configuration, billing, secrets, and control-plane Postgres access.
- `api-ts/` owns the data-plane API, ingestion/query paths, Brainstore integration, proxy/runtime behavior, and data-plane workers.
- Shared wire contracts belong in `@braintrust/typespecs`, `@braintrust/local-app-schema`, or `@braintrust/local-api-schema`, according to their audience.

Do not move a control-plane database query into `api-ts/` or a data-plane implementation into the app merely because both sides need a result. Define or reuse the authenticated API boundary and shared schema.

## App control-plane routes

Control-plane database code in `app/` must stay under `app/pages/api`, `app/app/api`, or `app/control-plane`. Keep the auth/RBAC check bundled with the query or include the repository's explicit RBAC disclaimer when a special case is necessary. Do not export an unauthenticated query helper for convenience.

For new JSON routes:

- Pages Router: use `runJsonRequest` from `app/pages/api/_request_util.ts`.
- App Router: use `runAppRouterJsonRequest` from `app/pages/api/_app_request_util.ts`.
- Server-action trampolines: use `invokeServerActionHelper` and pass the action argument schema when one exists.

Provide both an input schema and output schema. Let the harness parse request/auth context, attach tracing fields, map `HTTPError`, and validate serialized output.

For object CRUD, begin with helpers from `app/pages/api/_object_crud_util.ts`: `getObjects`, `makeFullResultSetQuery`, `patchObjects`, `deleteObjects`, and `setDeletedAtObjects`. Their `permissionInfo` keeps ACL filtering coupled to data access. Follow the dataset routes under `app/pages/api/dataset/` as the baseline pattern.

## Authorization is part of the query

Never treat a client-side permission check as authorization. Enforce authorization in the server operation that performs the read or mutation.

For control-plane SQL, build the authorized object set with `makeFullResultSetQuery` or the relevant established permission helper, and join/mutate through that set. Keep the required permission explicit (`read`, `update`, `create`, `read_acls`, and so on). If a query returns a `has_*_permission` sentinel, parse it and reject before returning domain rows.

In `api-ts`, route authenticated requests through `apiAuthorize` and consume the decoded `RequestContext` via `getRequestContext`. Use the established object/project/org permission helpers for the operation. Public health/version/OAuth endpoints are deliberate exceptions, not a reason to omit auth middleware from a new data endpoint.

Treat organization, project, object, user, and API-key IDs from the request as claims to verify, not authority by themselves.

## Audit logging

Mutations to projects, organizations, and `ai_secret` must be audit logged. Prefer CRUD helpers because they build audit entries consistently. For custom SQL or multi-step mutations:

1. derive the audit context from the authenticated request or headers;
2. perform the mutation and write its audit entry in the same database transaction when atomicity matters;
3. include the actual before/after or operation metadata expected by the audit schema;
4. test that unauthorized and no-op paths do not emit misleading entries.

Apply the same established audit helpers to other resources that already have audit behavior. Do not bypass an existing audited mutation helper with direct SQL.

## SQL and persisted data

Use parameterized SQL:

- In app control-plane code, add values through `SqlQueryParams` and pass `queryParams.params`.
- In `api-ts`, use `$1` parameters or the repository SQL template/tag helpers for values and identifier helpers for validated identifiers.
- Never interpolate request/provider values directly into SQL text.

Dynamic table names, columns, sort expressions, or SQL fragments must come from a closed validated mapping or established identifier helper. A string being TypeScript-typed is not sufficient validation.

Parse rows and JSON/JSONB with the owning Zod schema before returning them. Database reads are a serialization boundary. Keep SQL field names at the persistence edge and translate only after parsing when application code benefits.

Use the database transaction helpers already owned by the connection abstraction. Keep authorization, mutation, and audit writes in one transaction when they form one atomic operation. Close the transaction before external network calls unless the existing protocol explicitly requires otherwise.

## Data-plane route registration and compatibility

When adding an endpoint in `api-ts/src/api.ts`, add the matching Chalice route in `api/app.py` and include `OPTIONS` in its allowed methods. Keep CORS methods and exposed headers synchronized with the Express configuration where applicable.

Preserve mixed-version compatibility. Do not tighten a request or response schema, remove a legacy field, or change an existing route response shape without checking app, SDK, old data-plane, and self-hosted clients. Additive response fields consumed by the app should normally be optional/nullish on the app side.

## Errors and asynchronous work

Use the established exceptions and boundary mapping rather than introducing a parallel result framework into an existing route:

- app control-plane code uses `HTTPError` and the request harness's HTTP translation;
- `api-ts` uses its established `BadRequestError`, `ForbiddenError`, `NotFoundError`, `TooManyRequestsError`, `HTTPError`, and `getAPIErrorResponse` mapping;
- unknown defects become a generic 500 response while detailed context stays in structured logs/traces.

Do not expose raw internal errors, SQL, secrets, or provider payloads to clients. Preserve a stable error class/code/message when the app's known-error parser relies on it.

`api-ts` enforces `no-floating-promises`. Await or return every promise. Use `void` only for intentionally detached work whose owner handles rejection, shutdown, and observability.

## Logging and telemetry

- App code uses `#/utils/logger` with a stable namespace and `{ err: error }`.
- `api-ts` uses the request-scoped Pino logger from `api-ts/src/instrumentation/logger.ts`; request bindings and trace/span IDs are attached automatically.
- Put searchable structured fields in the first argument and a stable event message second.
- Preserve request IDs, trace context, and existing metrics around changed behavior.
- Never log raw auth tokens, cookies, API keys, secrets, provider credentials, or unnecessary personal data. Use redacted token previews and established sanitizers.

## OpenAI calls

For new OpenAI integration code in this repository:

- use a GPT-5-class model (`gpt-5-mini`, `gpt-5-nano`, or later);
- use the Responses API (`client.responses.create`), not Chat Completions;
- do not set token-limit parameters unless the user explicitly requests one;
- propagate real provider failures instead of substituting plausible-looking fallback data.

## Backend tests and review readiness

Co-locate Vitest tests with the implementation. Cover the highest practical authenticated boundary, including:

- malformed input;
- anonymous or insufficient permission;
- organization/project scope mismatch;
- successful read or mutation;
- output-schema rejection for malformed persisted/provider data;
- audit behavior for protected mutations;
- idempotency, rollback, or retry behavior when those paths exist.

Use `*.integration.test.ts` when a test requires the external integration suite; `api-ts/BUILD.bazel` separates it from unit tests. Use clearly testing-only aliases when direct pure-logic coverage is necessary, and avoid broadening production exports merely for tests.

When preparing or reviewing backend changes, also follow `.agents/skills/braintrust-backend-pr-pre-review/SKILL.md`.

## Canonical anchors

- `app/AGENTS.md`
- `app/pages/api/_request_util.ts`
- `app/pages/api/_app_request_util.ts`
- `app/pages/api/_object_crud_util.ts`
- `app/pages/api/_audit_log_util.ts`
- `app/pages/api/dataset/`
- `api-ts/src/api.ts`
- `api-ts/src/authorize.ts`
- `api-ts/src/request_context.ts`
- `api-ts/src/api_error.ts` and `api-ts/src/util.ts`
- `api-ts/src/instrumentation/logger.ts`
- `api-ts/BUILD.bazel`
- `api/app.py`
