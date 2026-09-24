# Frontend Architecture

**Status:** Architecture rules for Student, Teacher and Admin apps; no UI implementation is included.

**Source of truth:** [Planning Contract](../planning/PLANNING_CONTRACT.md).

## 1. Framework and rendering baseline

Use Astro + React + TypeScript + Tailwind CSS 4. Astro owns app routing, page composition and the default render path. React is added only for workflows whose interaction state or editing surface materially benefits from it. The three applications are not full SPAs by default.

Each app is a separate deployment and role-oriented experience:

- apps/student: enrolled Courses, published Lessons, Assessment availability, Attempt, autosave/resume, final submit, released result and safe profile.
- apps/teacher: assigned-Course dashboard, Lesson editor, Assessment/question editor and preview, submissions, grading, correction/regrade and release.
- apps/admin: school academic setup, membership and account state, Teacher assignment, Student enrollment and audit views.

Apps may share role-neutral presentation and contract packages. They do not share routes, app shells, role policy or business workflows by importing one app into another.

## 2. Static, SSR and hybrid decisions

| Screen/data type | Default rendering | Boundary |
|---|---|---|
| Public, user-independent help or product copy | Static Astro | Never include school or authenticated data |
| Personalized dashboard and Course list | Astro SSR when server rendering improves first view; otherwise Astro page with a small data island | User-scoped response; private/no-store cache policy |
| Lesson content | Astro SSR or client data fetch based on navigation needs | Published content only after current enrollment authorization |
| Assessment preview and result view | SSR for initial safe projection where useful; interactive island for editing/review | Results are visible only when release policy allows |
| Lesson/Assessment editors and grading screens | Astro route with React interactive surface | React owns local interaction; Worker/RLS remains authority |
| Assessment Attempt | Astro shell and React Attempt island | Durable answer state comes from server; UI must distinguish pending from acknowledged saves |

Never statically generate personalized Student, Teacher or Admin records, membership data, Attempts, grades or protected question data. Never publicly cache private HTML or API payloads. Route guards and SSR-only access are not security; all data access is still protected by RLS or Worker checks. If server rendering makes every request invoke a Pages Function, compare its quota cost with static shell plus authenticated data loading. Pages Functions count against Workers usage; see [Cloudflare Pages Functions pricing](https://developers.cloudflare.com/pages/functions/pricing/).

Cloudflare's Astro guide describes the Pages adapter for SSR and static deployment behavior: [Deploy Astro on Cloudflare Pages](https://developers.cloudflare.com/pages/framework-guides/deploy-an-astro-site/). Confirm current adapter/runtime support and usage at implementation and deployment time.

## 3. React island criteria

A React island is appropriate when the user needs a stateful, multi-step or high-frequency interactive surface:

- structured Lesson editor with ordered blocks and attachment selection;
- Assessment settings/questions/options editor, readiness feedback and Student preview;
- Attempt interface with answer drafts, debounce, acknowledged-save states, revision conflicts, offline/pending state and submit confirmation;
- manual grading with rubric/feedback editing;
- correction/regrade review and explicit result re-release;
- Admin tables with bulk selection, filtering or coordinated mutations.

Keep read-oriented screens Astro-first. A React island receives minimal safe initial data, owns transient interaction state and submits validated intent. It must not compute trusted score, authorization, publication version, server availability or release visibility as authority.

Do not create a React context/global state layer for data that belongs in PostgreSQL or Supabase Auth. Use form state for editable forms. Use ordinary fetch/server loading for isolated requests. Add a server-state library only when measured caching, deduplication, invalidation, retries or polling needs justify it; do not introduce one preemptively.

## 4. Forms and validation

Use TanStack Form with Zod as the standard for interactive React forms:

- Zod schemas shared from packages/schemas define client input shape and friendly synchronous validation.
- TanStack Form owns field/touched/submission state and field-level UI.
- On submit, send intent to the trusted Worker or a direct Supabase operation explicitly approved by the RLS matrix.
- Worker, database constraints and transactional functions validate authoritatively. Client Zod never grants access or makes a write trusted.
- Map safe server field errors back to fields; show request correlation IDs for recoverable failures without exposing database internals.

Native browser forms or Astro/server handling remain preferable for simple, low-interaction tasks where the request/redirect lifecycle is sufficient, such as a small sign-in action or basic profile update. Do not add a React island and TanStack Form to every form. Do not introduce React Hook Form or Formik.

## 5. React state and no-useEffect rule

First-party React code must not directly call useEffect. Keep the constraint intact.

Preferred approaches:

- Astro/server data loading for request-time initial data.
- Derived state from props, form values and query results instead of copying values into separate state.
- Event handlers for user-triggered network calls and state transitions.
- TanStack Form for input state and submit lifecycle.
- Explicit server-state library for justified cache/retry/subscription behavior, using its supported APIs.
- Callback refs for imperative element integration where a ref lifecycle is needed.
- Framework or library APIs designed for resource lifecycles, subscriptions and cleanup.
- CSS and native browser behavior for presentational interactions.

Do not hide a direct useEffect behind a custom hook. If an integration truly requires a React effect lifecycle and cannot be expressed through these alternatives, record the exact integration class, cleanup/error behavior and reason in a reviewed ADR before adding a narrowly scoped exception. That exception would revise the contract; this document does not grant one.

## 6. Shared UI and design system

Shared visual primitives live in packages/ui and follow the project's shadcn/ui approach with an approved non-Radix implementation. Do not add or import any @radix-ui/* dependency.

Shared components may own accessible interaction mechanics, variants and styling, but not Student/Teacher/Admin business meaning, data access, school authorization, Assessment rules, routes or product copy that encodes role policy. App-level components compose shared primitives into role workflows.

For each primitive, document keyboard behavior, focus management, labels and disabled/error states. Since a non-Radix path is constrained, verify maturity, accessibility, maintenance and React compatibility before selecting a specific primitive. Do not manually recreate complex dialog, menu or combobox semantics without an accessibility review.

## 7. Accessibility and responsive behavior

- Meet the applicable WCAG 2.2 AA target for critical learning and assessment flows.
- All actions work by keyboard with visible focus and logical tab order.
- Inputs have programmatic labels and clear inline errors; status changes such as Saving/Saved/conflict are announced accessibly.
- Do not communicate correctness or save state by color alone.
- Preserve readable layout at mobile widths; Assessment answer controls and submission confirmation must work on small screens.
- Respect reduced motion and zoom/text resizing.
- Math, formulas, PDFs, media controls and external video embeds require accessible labels/alternatives or a documented limitation before release.

## 8. Authentication and rendering safety

For Astro SSR, use per-request Supabase clients and validated session claims. Do not use a process-global user client, trust cookie contents without verification, or place access tokens in rendered HTML, URLs, logs or shared caches. The Supabase SSR cookie is shared with the browser client and therefore is not HttpOnly; treat it as XSS-sensitive, use strict CSP and safe rendering, and validate origin/CSRF on cookie-authenticated same-origin mutations. Worker API calls send the current access token over HTTPS in an explicit Authorization header with exact-origin CORS; do not use cross-origin API cookies or store long-lived credentials in localStorage. Pin and test the selected SSR package and Astro adapter because Supabase currently documents @supabase/ssr as beta.

Initial route checks may improve navigation UX, but the data query still depends on RLS or Worker authorization. A page rendering successfully is not evidence that later database requests are safe.

## 9. Package and data ownership

- packages/ui: role-neutral components and tokens.
- packages/schemas: Zod request/form schemas and safe response projections.
- packages/auth: Supabase session/client adapters; no role authority.
- packages/database: generated database types/client boundaries.
- packages/domain: stable domain types/rules; no UI code.
- packages/config: build and quality settings.
- apps own route shells, app-specific copy, data composition and role-specific interaction.

Dependency direction is apps → packages. Shared packages never import apps; apps never import one another; package dependency graphs remain acyclic. Keep business logic out of UI components and do not introduce generic utils/common packages.

## 10. Quota and performance considerations

Static assets are preferable where content is safe to publish. Pages SSR/Functions can consume Worker request/CPU allowance; SSR must therefore be selective. A Student Attempt saves only meaningful changed answers after a debounce/coalesce window; every keystroke is not a request. The autosave reliability target remains durable persistence within five seconds under the healthy-network test profile, not a promise based on browser state.

Measure Student LCP against the 2.5 second planning target, critical interaction latency against the 200 ms target where measurable, and answer durability under representative network and submit-burst tests. Avoid sending large Assessment versions repeatedly; use bounded safe projections and avoid exposing answer keys in initial props or serialized page state. Re-verify provider quotas at deployment.
