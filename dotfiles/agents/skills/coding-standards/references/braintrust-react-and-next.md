# Braintrust React and Next.js conventions

Use this reference for product work in `app/`. Read `app/AGENTS.md` completely first; it is the canonical and more frequently updated source.

Also read [`braintrust-monorepo-and-typescript.md`](braintrust-monorepo-and-typescript.md).

## Server and client boundaries

Keep control-plane database code under one of the guarded roots:

- `app/pages/api/**`
- `app/app/api/**`
- `app/control-plane/**`

Pages and route components obtain control-plane data through `#/control-plane/...` helpers. They do not import database clients or reach into `pages/api` database implementation helpers directly. Keep authorization/RBAC coupled to the query that depends on it.

Prefer a server component until the component needs browser APIs, event handlers, or client hooks. Put `"use client"` at the narrowest useful boundary. Mark modules that must never enter a browser bundle with the established `server-only` pattern when neighboring modules do so.

Never call a React Server Action implementation directly from client code. Use `invokeServerAction` from `#/utils/invoke-server-action`, import the action only as a type, pass Clerk's `getToken`, and provide the matching `app/app/api/actions/{fName}/route.ts` trampoline. Generate that route with `scripts/generate_server_action_route.py`.

For a server-action-backed query, prefer `useQueryFunc` from `#/utils/react-query`. It supplies the action invocation and query-key convention. Include every input that changes the result in `args` or `keyArgs`, use `enabled` when required identity is unavailable, and invalidate or update the same query after a mutation.

Use the established data-plane fetch helpers in `#/utils/btapi/fetch` and BTQL helpers in `#/utils/btql` instead of open-coding authentication, fallback transport, or response parsing.

## State ownership

Match state to its lifetime:

- Keep transient component interaction state local.
- Use the existing `ProjectContext`, organization/user contexts, and route context for data already owned by those providers.
- Use TanStack Query for remote/server state, loading/error state, caching, and invalidation.
- Use Jotai for shared feature state that is client-only and has multiple consumers; keep feature atoms with the feature unless they are genuinely app-wide.

Do not copy provider-owned data into a second state system without an explicit synchronization requirement. Derive filtered, sorted, or indexed views with pure helpers or memoization when the computation or referential stability warrants it.

React Compiler lint rules are enabled. Do not set state during render, mutate values read by React, create components inside render, or omit hook dependencies. Do not add manual memoization mechanically; preserve existing memoization when the compiler rule requires it and use it where identity is observable or computation is material.

## Shared UI and styling

Build product UI from shared primitives before creating a local substitute:

- Use `Button` and `buttonVariants` from `#/ui/button`; extend its variants when a reusable appearance is missing instead of styling raw `<button>` elements.
- Use existing dialog, sheet, dropdown, form, input, tooltip, and confirmation primitives under `app/ui`.
- Compose conditional class names with `cn` from `#/utils/classnames` so Tailwind classes merge correctly.
- Use `StyledDndContext`, not `DndContext` directly.
- Import the wrapped `toast` from `#/utils/toast`; direct `sonner` toast use belongs only in the wrapper/toaster implementation.

Follow the interaction details in `app/AGENTS.md`:

- Shared buttons already own disabled opacity and pointer behavior; do not add `cursor-not-allowed`.
- Wrap a disabled tooltip button in a hoverable element inside `TooltipTrigger asChild`.
- Do not add `cursor-pointer` to shared dropdown items.
- Add `select-none` to clickable text controls, but not to selectable text or text inputs. Shared `Button` already includes it.
- Animate conditional dialog rows, validation, hints, and height changes with `AnimatedCollapsibleSection`; keep each trigger and its collapsible content in one spacing wrapper.
- Let removable rows finish their exit animation before removing backing data.
- Do not animate textarea resizing.

Prefer readable branches, early returns, named booleans, and small helpers over nested ternaries, long `&&` chains, or multiple conditional spreads in one literal.

## Interaction, navigation, and security details

- Explain why each `stopPropagation()` or `preventDefault()` call is necessary on the same line or immediately above it.
- Give every `<iframe>` a `sandbox` attribute.
- Set `prefetch={false}` on Next `Link` components whose `href` starts with `/docs`.
- Keep complete hook dependency arrays, including custom `useBtql` hooks.
- Use sentence case for UI labels, headings, actions, and error titles.

## Errors and logging

Use `toast.knownError(parseKnownError(error))` for recognizable user-facing failures. Put reusable recognition and presentation in `app/utils/known-errors`; do not construct a local `KnownError` at a feature call site. Pass only a contextual title override when the feature needs one.

Import `getLogger` from `#/utils/logger` instead of adding `console.*` in production app code. Use a stable namespace. Put structured searchable fields first and the human-readable event second; pass exceptions as `{ err: error }` so Pino serializes and redacts them consistently.

Do not put secrets, credentials, email addresses, Slack identifiers, or raw provider payloads into logs. The shared logger redacts known fields, but redaction is a backstop rather than permission to log sensitive data.

## React tests

- Co-locate Vitest files as `*.test.ts` or `*.test.tsx` beside the behavior.
- App Vitest defaults to a Node environment. Add `/** @vitest-environment jsdom */` only for tests that render DOM or use browser APIs.
- Use Testing Library to exercise visible behavior and user interaction rather than component internals.
- Wrap query-dependent components in a real `QueryClientProvider` with a fresh `QueryClient` per test.
- Do not mock the logger or spy on `console` to assert logging. Use `createLoggerForTest`, `pino-test`'s `sink`, and emitted structured records.
- If private pure logic needs direct tests, prefer a clearly testing-only alias over broadening the production API.

Module mocks exist in app tests for hard framework and integration boundaries. Use them narrowly, reset their state, and do not mock a module when a pure helper, real provider, recording implementation, or request-level test gives stronger coverage.

## Canonical anchors

- `app/AGENTS.md`
- `app/eslint.config.js` and `app/.oxlintrc.json`
- `app/utils/invoke-server-action.ts`
- `app/app/api/actions/util.ts`
- `app/utils/react-query.ts`
- `app/utils/btapi/fetch.ts`
- `app/ui/button.tsx`
- `app/ui/animated-collapsible-section.tsx`
- `app/utils/toast.ts`
- `app/utils/known-errors/design.md`
- `app/utils/logger.ts` and `app/utils/logger.test.ts`
