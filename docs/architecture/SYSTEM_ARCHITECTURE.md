# System Architecture

**Status:** Phase A architecture specification; accepted as the implementation baseline, not yet implemented.

**Source of truth:** [Planning Contract](../planning/PLANNING_CONTRACT.md).

**Product:** School-scoped LMS with first-class Assessment integrity.

## 1. System context and product boundaries

The product supports the learning loop:

~~~text
Manage → Teach → Learn → Assess → Review → Correct
~~~

It owns school-scoped academic structure, structured learning content, Assessment publication and Attempts, grading, controlled result release, and auditable correction. It is not a general school CMS, student information system, ERP, public school website, or generic form builder.

~~~mermaid
flowchart LR
  Student[Student browser] --> StudentApp[apps/student]
  Teacher[Teacher browser] --> TeacherApp[apps/teacher]
  Admin[Admin browser] --> AdminApp[apps/admin]
  StudentApp -->|safe user-scoped requests| Supabase[Supabase Auth + PostgreSQL / RLS]
  TeacherApp -->|safe user-scoped requests| Supabase
  AdminApp -->|safe school-scoped reads| Supabase
  StudentApp -->|trusted mutations / Worker API| Worker[apps/worker]
  TeacherApp -->|trusted mutations / Worker API| Worker
  AdminApp -->|privileged school operations| Worker
  Worker -->|user JWT + narrow RPC| Supabase
  Worker -->|short-lived signed operations| R2[Private Cloudflare R2]
  StudentApp -->|authorized direct object transfer| R2
  TeacherApp -->|authorized direct object transfer| R2
  AdminApp -->|authorized direct object transfer| R2
~~~

## 2. Application responsibilities

| App | Owns | Runtime boundary |
|---|---|---|
| apps/student | Student dashboard, enrolled learning content, published Assessment experience, Attempt/autosave/submit UI, released results, safe profile view | Astro on Pages; use static output only for non-personalized content, SSR for private server-rendered views when useful, React islands for interactive Attempt flows |
| apps/teacher | Assigned-Course dashboard, Lesson and Assessment authoring, preview, submissions, manual grading, correction/regrade and release UI | Astro on Pages; React islands for editors, grading and other stateful workflows |
| apps/admin | School-scoped academic setup, membership/account state, assignment/enrollment and audit views | Astro on Pages; React islands only for complex tables and workflows |
| apps/worker | Trusted API for authorization-sensitive, privileged, multi-record and transactional operations; R2 signing; safe error responses | TypeScript Cloudflare Worker; independent deployable API and secret boundary |

The apps own routing, presentation, UX validation and orchestration of their own views. No app imports another app. The browser is untrusted; route guards and hidden controls are not authorization.

## 3. Package responsibilities and dependency direction

| Package | Sole ownership |
|---|---|
| packages/ui | Role-neutral accessible visual primitives and composition; no app routing, school/role checks, domain decisions or data access |
| packages/schemas | Shared request/response and form schemas, primitive validation and safe projections; no database calls or app imports |
| packages/database | Generated Supabase database types, typed client setup boundaries, migration-related type artifacts; no product authorization decisions |
| packages/auth | Supabase client/session helpers and verified identity context adapters for Astro and Worker; no source of role truth |
| packages/domain | Framework-independent LMS rules and domain types shared by trusted code; no app dependencies, HTTP, storage SDK or privileged credentials |
| packages/config | Shared TypeScript, lint, formatting, Tailwind and build configuration; no runtime business behavior |

Allowed direction:

~~~text
apps → shared packages
Worker → domain / schemas / database / auth / config as needed
Astro apps → ui / schemas / auth / database types / config as needed
domain → schemas (only for stable domain contracts)
~~~

Shared packages never depend on apps. Packages must not form cycles. Database-specific code cannot become the place for duplicate business rules: database constraints/RPC enforce atomic integrity; domain code validates intent; policies enforce access. Avoid packages named utils or common. Promote a helper only when it has a clear owner, consumers and stable contract. Package details and exact imports are settled during foundation implementation without changing these boundaries.

The repository uses pnpm workspaces with Turborepo to orchestrate TypeScript app/package tasks. Supabase CLI and PostgreSQL migration workflows remain explicit root tasks; Turborepo does not own or replace the migration source of truth.

## 4. Deployment topology

- Deploy Student, Teacher and Admin Astro applications independently to Cloudflare Pages where their rendering mode is supported.
- Prefer static generation for public or user-independent content. Do not statically publish private school, membership, Student, Attempt, grade or answer data.
- Use Astro SSR only for views whose server rendering provides a concrete UX/data-loading benefit. Personalized SSR must disable shared caching and must not leak one user's output to another.
- Pages Functions are an optional runtime path for limited app-local SSR, not a second business backend. Dynamic functions consume Worker allowances; keep trusted business mutations in apps/worker.
- Deploy apps/worker as the trusted API, on an explicit API origin. Permit only the known application origins through CORS. The Worker receives Supabase access tokens as bearer credentials, validates identity and current authorization, then calls a narrow database RPC for atomic writes.
- Supabase Auth issues and verifies user identity. Supabase PostgreSQL stores academic records and applies mandatory RLS. R2 stores private binary objects.
- Browser-to-R2 transfers use short-lived signed URLs issued after Worker authorization. Permanent storage credentials remain in Worker secrets.
- No frontend app shares secrets or runtime state with another app. The Worker and each app have separate deployment configuration, environment variables and health checks.

Cloudflare's current Workers pricing documentation describes a Free allowance of 100,000 requests/day and 10 ms CPU per invocation; Pages Functions use Workers billing. Those values are constraints to recheck before deployment, not capacity guarantees. Astro's Pages deployment guidance distinguishes static output from adapter-backed server rendering. See [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/), [Pages Functions pricing](https://developers.cloudflare.com/pages/functions/pricing/), and [Astro on Pages](https://developers.cloudflare.com/pages/framework-guides/deploy-an-astro-site/).

## 5. Request and data flows

### Safe scoped read

Browser obtains a Supabase session and uses a user-scoped Supabase client. RLS evaluates the authenticated identity, school membership and specific enrollment/assignment relation. Queries request only safe columns and published projections. A resource ID is never authorization.

### Trusted state change

~~~text
Browser → Worker
  authenticate token
  authorize current school membership + role + assignment/enrollment
  validate input
  apply domain rule
  call one narrow database RPC
  PostgreSQL transaction rechecks necessary ownership/state
  mutate rows + required audit event atomically
  return minimal safe projection
~~~

A sequence of unrelated Supabase REST calls is not a transaction. Publication, Attempt start, answer compare-and-set, final submit/grading, grade revisions, release, correction/regrade and re-release must use a narrowly scoped PostgreSQL transaction/RPC or another database-level atomic mechanism. Never expose a generic SQL execution API. Prefer user JWT/RLS context for user-owned database mutations. Any privileged Auth Admin operation stays server-only and is separately authorized and audited.

### Private file transfer

Worker authorizes school, course, role and metadata context, creates a server-generated object key such as school/{school UUID}/course/{course UUID}/asset/{asset UUID} (no user-supplied path or PII), and returns a short-lived R2 operation bound to the method, key and expected content type. Browser transfers bytes directly. A completion step verifies object identity, configured size/MIME policy and records metadata. Downloads require a fresh authorization decision. The bucket stays private and the R2 object key is not an access control. Exact MIME allowlist, byte limits and URL TTL are configuration decisions made and tested before upload implementation. An uncompleted upload remains an unreferenced private object; MVP cleanup can be manual/operational until measured volume justifies lifecycle or scheduled cleanup.

## 6. Responsibility matrix

| Capability | Primary owner | Enforcement |
|---|---|---|
| Identity and sessions | Supabase Auth | Verified access token; secure app session handling |
| School roles, active status | PostgreSQL memberships/roles | RLS and Worker current-state checks; never user-editable metadata |
| Student/Teacher scope | PostgreSQL enrollment/assignment relations | RLS for direct queries; Worker and transaction check for mutations |
| Academic records, Assessment state, Attempts/results | Supabase PostgreSQL | Foreign keys, unique constraints, RLS, transactional RPC |
| Trusted workflow orchestration | apps/worker | Authentication, authorization, validation, safe projections |
| Binary Lesson/Question files | Cloudflare R2 | Private bucket, Worker-issued short-lived signatures |
| Presentation, forms, local interaction | Astro/React apps | UX only; never security authority |
| Durable academic audit | PostgreSQL audit_events | Written with state transition in the same transaction where practical |
| Database schema evolution | Supabase CLI migration files | One reviewed, version-controlled migration source |

## 7. Trust boundaries and security baseline

- Supabase Auth is the sole authentication authority.
- PostgreSQL RLS is mandatory for every browser-accessible table/view/function path; least-privilege grants are required in addition to policies.
- Worker authorization checks current school membership, role, enrollment or explicit Course assignment. JWT role claims are not authoritative for mutable school roles.
- Service-role secrets are server-only and are not used as a shortcut around per-user authorization. Never expose them to a browser bundle, static output, logs or source control.
- Protected answer keys live in a separate trusted structure with no Student grants or RLS policy that permits Student reads. Student question projections omit keys by construction.
- Grade and result reads are visible to the Student only after explicit release and only for that Student.
- Every protected aggregate has school ownership directly or through constrained parent relationships. Composite constraints prevent cross-school links.
- Resource identifiers do not grant access. Denial is the expected behavior for invalid school, role, Course, membership, lifecycle or ownership context.

The database security model follows Supabase's guidance that RLS policies should be paired with grants and that service-role credentials bypass RLS; database functions used for writes must have carefully scoped execution rights. See [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) and [database functions](https://supabase.com/docs/guides/database/functions).

## 8. Transaction and retry strategy

Each user-visible academic state transition has one database-owned transaction boundary. The Worker performs input normalization and early authorization, but the database transaction checks the state and ownership again under the relevant lock/conditional update. A retried request either returns the canonical existing outcome or an explicit conflict; it cannot duplicate a publication, submission, grade revision, release, correction or audit action.

Required atomic boundaries:

- publish a complete immutable version, update current-version pointer and write audit;
- create one Attempt pinned to a version under the one-Attempt policy;
- save an answer only when its expected revision matches and Attempt remains IN_PROGRESS;
- transition Attempt once to SUBMITTED, store one timestamp, grade objective items and create the result/revision once;
- commit manual grading and its grade revision/audit together;
- create correction and regrade records, apply each affected Attempt at most once, preserve manual grades, and mark released outcomes for review;
- release or explicitly re-release a particular grade revision and write audit.

Detailed state and race semantics are specified in [Assessment Integrity](ASSESSMENT_INTEGRITY.md). Database migrations have a single owner: supabase/migrations. Supabase's CLI workflow treats schema changes as version-controlled migrations; generated TypeScript types are derived artifacts. See [Supabase CLI migration workflow](https://supabase.com/docs/guides/local-development/cli-workflows).

## 9. Health, errors and observability

- Assign a correlation/request ID at the Worker edge and return it on every response.
- Return a stable safe error envelope with machine-readable category and correlation ID. Do not expose SQL, stack traces, tokens or internal object keys.
- Emit structured, redacted logs for authentication failures, authorization denials, database failures, autosave conflicts/errors, submit failures, grading/regrade failures, R2 signing failures and quota/latency thresholds.
- Never log secrets, JWTs, passwords, complete Student answer payloads, protected correct-answer payloads or presigned bearer URLs.
- A health endpoint reports process/configuration readiness without secrets or private records. Deployment smoke checks separately verify Supabase auth, a representative RLS read, a harmless RPC and R2 signing against test resources.
- Monitor request count, CPU time, error rates, database latency/connection failures, autosave durability, submission races, grading/regrade outcomes and R2 authorization failures. Configure alarms before the real pilot using the available free-tier observability or an accepted cost plan.
- Keep logs for incident diagnosis without treating operational logs as the academic audit record.

## 10. Free-tier constraints and capacity gate

The selected architecture is designed to fit the free-first deployment choice, but a provider allowance is not a reliability promise. Planning evidence records Workers Free at approximately 100,000 requests/day and 10 ms CPU/invocation; Supabase Free at shared Nano compute, 500 MB database, connection/pooler limits, possible inactivity pause and no managed automatic backup; and R2 Standard free allowances for storage and operations. Recheck all quotas, pauses, billing rules and backup behavior before deployment. The initial real pilot remains one school, one class, one Teacher and 20+ Students. The 100 concurrently active Attempt workload is a separate validation profile, not the pilot headcount. Do not call the stack pilot-safe until measured autosave, submit burst, authorization, failure/retry and backup/restore tests pass.

## 11. Upgrade path

Keep the same TypeScript contracts, Postgres schema, RLS policies and R2 object model when moving from free allowances to paid plans. Upgrade the existing services before adding another backend or changing product trust boundaries. Introduce queues, an additional runtime, or a different backend only after measured workload and operational evidence, with an ADR and planning-contract revision. Laravel remains an evaluated, deferred option, never a parallel business-logic backend in this baseline.
