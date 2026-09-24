# Authorization and Trust Model

**Status:** Required security architecture for the implementation baseline.

**Source of truth:** [Planning Contract](../planning/PLANNING_CONTRACT.md).

**Primary rule:** browser role checks are UX; Supabase RLS and trusted Worker/database checks enforce access.

## 1. Trust model

~~~text
Supabase Auth identity
        ↓ verified access token
Current PostgreSQL membership + role + enrollment/assignment
        ↓
RLS for direct user-scoped database requests
        +
Worker authorization and narrow transaction RPCs for privileged workflows
~~~

Supabase Auth is the only authentication provider. The stable identity is auth.users.id. profiles.id references that ID. School membership, role, active/disabled state, Course assignment and Student enrollment live in protected PostgreSQL tables, not user-editable Auth metadata.

Every request is untrusted until authenticated. A resource ID, route name, submitted school_id, hidden button or frontend role check is never proof of authority. Authorization is recomputed from the current school membership and the relevant Course relation. Disabled membership has no school capabilities even if its JWT has not expired.

## 2. Authentication flows

### Astro applications

The apps use Supabase Auth with PKCE. For Astro SSR, use a request-scoped Supabase client backed by the Supabase SSR cookie flow and refresh handling; never put a user session in a shared server singleton or static HTML. The shared Supabase session cookie must be readable by the browser client, so it is not HttpOnly; use host-only, Secure, SameSite=Lax cookies and treat its contents as XSS-sensitive. Use a strict Content Security Policy, safe rendering and CSRF/origin validation for cookie-authenticated state-changing same-origin endpoints. Worker API calls use an explicit Authorization: Bearer header with exact-origin CORS rather than ambient cross-origin cookies. Never shared-cache personalized responses.

Astro's Supabase SSR guidance describes cookie-based server rendering; Supabase currently describes @supabase/ssr as beta, so pin the selected version and test the Cloudflare adapter, refresh, logout and token validation flow during foundation work: [Supabase SSR guidance](https://supabase.com/docs/guides/auth/server-side), [Astro quickstart](https://supabase.com/docs/guides/auth/quickstarts/astrojs).

### Worker API

Each app sends a Supabase access token in an Authorization Bearer header to the Worker. The Worker verifies the token signature/issuer/audience/expiry using a Supabase-supported verifier or trusted JWKS path, then resolves the user ID. It loads current membership, active role, enrollment or assignment from PostgreSQL for the requested school and resource. Do not accept actor ID or role from request JSON.

Worker mutation handlers follow:

1. assign correlation ID and parse bounded input;
2. authenticate the bearer token;
3. resolve current membership and resource scope;
4. authorize the requested action;
5. validate domain invariants;
6. call the one narrow transactional RPC using the user JWT/RLS context where appropriate;
7. return a minimal safe projection and correlation ID.

The Supabase service-role credential is not a normal query credential. Keep it server-only and use it only for narrowly required Auth Admin operations and Worker-only transaction RPCs that enforce the route boundary. For identity mutations, the Worker first authenticates the caller and checks current Admin membership through the user-scoped RLS client; the RPC accepts only the Worker-derived actor ID and rechecks active Admin membership in the same transaction. Grant service_role execution only on the named functions, revoke it from browser roles, and never expose it to browser code. No Worker handler may use the service client for general table reads or writes.

## 3. Roles and school scope

- **Student:** active school membership with Student role, and active class/year enrollment for the Course. May access own profile, enrolled Courses, published Lessons, eligible published Assessment projections, own Attempt/answers, and own explicitly released result. Cannot read drafts, answer keys, other Students' work, unreleased grades or unenrolled Courses.
- **Teacher:** active school membership with Teacher role and active assignment to the specific Course. May access that Course's Lessons and Assessment authoring, submissions, manual grading, correction and result release. Assignment to one Course gives no authority over sibling Courses.
- **Admin:** active school membership with Admin role. May manage school structure, memberships, account school-status, assignments/enrollments and school-scoped audit. Admin role does not imply Teacher role or grant a Teacher-only action; an Admin who also teaches needs an explicit Teacher role and Course assignment.

A user may have multiple explicit roles, but every operation selects the required role and Course scope. Cross-school membership in the future does not create cross-school authority.

School account disable/reactivation changes the school's membership status, roles/assignments as policy requires, and the durable audit record in one trusted transaction. It does not globally ban the Supabase Auth identity because that identity may hold another school membership. Creating/inviting an Auth identity is a Worker-only Auth Admin action followed by a separate database membership grant; until the membership and explicit role commit, the identity has no school access. Auth and PostgreSQL do not share a transaction, so retries must be idempotent and a failed membership grant leaves only an unprivileged identity for a safe retry/cleanup. Invitation and password recovery delivery details remain implementation choices.

## 4. Direct Supabase versus Worker matrix

Direct browser access is allowed only where grants and RLS fully express the complete authorization rule, projections exclude protected fields, and automated allow/deny tests cover the path. Direct access is a constrained option, not a requirement to avoid the Worker.

| Operation | Actor | Direct Supabase + RLS | Worker | DB RPC/transaction | Reason |
|---|---|---:|---:|---:|---|
| Read own safe profile | Student/Teacher/Admin | Yes | No | No | Auth user ID and same-school membership row; safe columns only |
| Read enrolled Courses | Student | Yes | No | No | Membership active and enrollment to Course class/year |
| Read published Lessons | Student | Yes | No | No | Same enrollment plus published status; no draft content |
| Read assigned Courses | Teacher | Yes | No | No | Active Teacher role and explicit assignment |
| Lesson draft CRUD | Assigned Teacher | Yes, if policy-tested | Optional | Only if a multi-row publish/audit action is added | RLS checks active assignment and draft ownership/state; no client privilege |
| Publish/archive Lesson | Assigned Teacher | Yes, if the transition is one-row and policy-tested | No | No | RLS requires active assignment and a valid state transition; published Student reads remain enrollment-scoped |
| Read school structure | Admin | Yes, scoped | No | No | Read-only school membership policy |
| Create/edit/archive school academic structure | Admin | No | Yes | Yes where constraints or audit span rows | Trusted school-scoped admin operation; database checks parent ownership and appends required audit |
| Admin user/account/membership management | Admin | No | Yes | Yes for atomic school status + audit; Auth Admin only if needed | Privileged identity operation; never accept requested role as authority |
| Teacher assignment | Admin | No | Yes | Yes | Validate same school, active Teacher role, course; audit atomically |
| Student enrollment/unenrollment | Admin | No | Yes | Yes | Validate same school, Student role, class/year; preserve history and audit |
| Assessment draft CRUD including keys | Assigned Teacher | Yes, only with separate tested policies | Optional | No for individual draft edits; yes for publication | Draft/key policies expose only assigned Teacher; Student has no key grants |
| Readiness validation / Student preview | Assigned Teacher | Read-only draft data may be direct | Yes for canonical readiness/projection | Optional pure validation RPC | Keep preview Student-safe and publication validation authoritative |
| Read eligible published Assessment projection | Enrolled Student | Yes | No | No | RLS requires active enrollment, published state and current availability; projection contains no keys |
| Read a published answer key for authorized review | Assigned Teacher | No | Yes, through an explicit scoped projection | Read-only scoped query/RPC | Needed for Teacher review/correction; published key rows have no direct browser grant and Student projection remains key-free |
| Publish Assessment | Assigned Teacher | No | Yes | Yes | Snapshot, pointer and audit are atomic |
| Start Attempt | Student | No | Yes | Yes | Eligibility, current version and one-Attempt uniqueness are race-sensitive |
| Read own Attempt, saved answers and safe questions | Student | Yes | No | No | Own rows under RLS; version-safe projection excludes key; answers are read-only to browser |
| Answer autosave | Student | No | Yes | Yes | CAS revision must serialize with final submit |
| Final submit | Student | No | Yes | Yes | Canonical state transition, timestamp, objective grading and result creation |
| Objective grading | System on submit | No | Orchestrates | Yes, same submit transaction | Score derives only from trusted version key and persisted answers |
| Manual grade commit | Assigned Teacher | No | Yes | Yes | Grade revision, feedback, state and audit are atomic |
| Read own released result | Student | Yes | No | No | Own result and released-revision pointer only |
| Result release/re-release | Assigned Teacher | No | Yes | Yes | Explicitly selects revision; audit and visibility pointer are atomic |
| Create Assessment correction | Assigned Teacher | No | Yes | Yes | Immutable correction record and audit |
| Regrade | Assigned Teacher | No | Yes | Yes, retry-safe | Apply at most once per affected Attempt; preserve manual grades |
| R2 upload authorization | Authorized Teacher/Admin | No | Yes | Yes for upload intent/metadata | Worker authorizes generated private object key and short-lived signature |
| R2 download authorization | Eligible Student/Teacher/Admin | No | Yes | Read/check as needed | Each request checks current Course/role or result visibility |
| Append required audit event | Trusted action | No direct browser insert | Yes | Yes, same transaction where practical | Client cannot forge actor, before/after state or outcome |
| Read school audit history | Admin; scoped Teacher academic history as product permits | Yes only under narrow RLS | Optional | No | Read-only scoped query; do not expose unrelated school/member data |

No direct access is permitted to Supabase Auth admin endpoints, service-role operations, protected answer-key rows, unrestricted database functions, or private R2 credentials.

### Identity and academic-structure operations

| Operation | Browser direct Supabase + RLS | Worker API | Database boundary |
|---|---:|---:|---|
| Read own safe profile and current membership/roles | Yes | No | RLS limits rows to the caller; only safe columns are selected |
| Read school-scoped academic structure | Yes | No | RLS limits Admin to its school, Teacher to assigned Courses and Students to enrolled class/year Courses |
| Update own display name | Yes | No | Column-level grant plus self-only profile policy |
| Create academic year, class, subject or Course | No | Yes | Worker verifies current Admin membership, then calls one service_role-only RPC; RPC rechecks actor and commits audit atomically |
| Grant/revoke role or disable/reactivate membership | No | Yes | Same narrow Worker-only RPC path; actor is derived from verified Supabase Auth identity |
| Assign/revoke Teacher or enroll/unenroll Student | No | Yes | Same narrow Worker-only RPC path; same-school keys, role checks, uniqueness and audit are database enforced |
| Direct table insert/update/delete for school administration | No | No | Authenticated and anonymous DML grants are revoked; privileged changes exist only through named RPCs |

The service-role key is configured only as a Cloudflare Worker secret (`SUPABASE_SERVICE_ROLE_KEY`) and is never sent from a browser. The Worker uses the caller's bearer token for identity verification and RLS-scoped Admin lookup; it creates a separate service client only after those checks. The SQL RPC checks the supplied actor against current membership state to close a time-of-check/time-of-use gap. The RPC does not accept an actor ID from request JSON. Authenticated users cannot execute these RPCs directly, even if they are Admins.

## 5. RLS policy architecture

Enable RLS on every table exposed through Supabase APIs. Revoke broad grants first; grant only required operations and columns/projections. A permissive policy is not a replacement for a narrow grant. Use security-invoker views or explicit column-safe RPC projections where they reduce accidental leakage; verify view/function execution semantics under the deployed PostgreSQL version.

Policy predicates use auth.uid() and relational ownership checks:

- **School isolation:** each read/write row must have a current active school_membership for the same school and the required role.
- **Teacher assignment:** Course-owned write/read rows require active Teacher role plus active teacher_assignment for that exact Course.
- **Lesson lifecycle:** Lesson row updates require active Teacher role plus active assignment to the exact Course; Student reads require published status and active enrollment. If publish later spans required audit/media checks, move that transition to Worker/RPC before adding those behaviors.
- **Student enrollment:** Course reads require active Student role plus active class/year enrollment matching the Course.
- **Own Attempt:** Attempt and answer reads require student_membership.user_id = auth.uid(); no policy allows reading another Student's rows.
- **Published content:** Student policies require Lesson published; Assessment/question projections reference the current published version and eligibility. Drafts and mutable authoring tables are Teacher-only.
- **Answer keys:** Student has no key-table grant or policy and Student projections never return key fields. Assigned Teachers may edit mutable draft keys through their scoped policy and may request a published-key projection only through an explicit Worker operation for an assigned Course. Published key rows are never directly selectable from the browser.
- **Released result:** Student can read only a result whose Attempt belongs to that Student and whose released revision pointer is non-null and current disclosure state permits visibility.
- **Attempt writes:** Students cannot directly update Attempt status, grade, submitted_at, or answer rows through table update. Autosave and submit use the Worker RPC boundary.
- **Audit writes:** browser roles cannot insert or update audit events. Read access is a narrow school-admin (and any explicitly approved academic scope) policy.

PostgreSQL RLS and grants are both required; service-role access bypasses RLS and must be treated as privileged. See [Supabase RLS documentation](https://supabase.com/docs/guides/database/postgres/row-level-security). Database functions must not become an unguarded bypass; use invoker rights by default and tightly scope any definer function, search path, grants and explicit authorization checks: [Database functions](https://supabase.com/docs/guides/database/functions).

## 6. Required denial and allow test matrix

| Scenario | Expected result |
|---|---|
| Student A queries Student B profile-private data, Attempt, answers or result | Denied / no rows |
| Student requests a Course outside enrolled class/year | Denied / no rows |
| Student reads unpublished Lesson or Assessment draft | Denied |
| Student selects protected answer-key table or attempts RPC | Denied |
| Assigned Teacher requests published key for own Course through approved Worker review route | Allowed as a minimal Teacher-only projection; direct table read remains denied |
| Unassigned Teacher requests published key | Denied by Worker and database scope check |
| Student reads a result before release or after review-required correction | Denied/old released revision according to explicitly maintained release pointer; never new unreviewed score |
| Teacher without assignment queries another Course's Lessons, submissions or Assessment | Denied |
| Teacher assigned to Course A submits Course B ID | Denied by policy and Worker check |
| Admin from School A reads or mutates School B records | Denied |
| Active user has stale token but membership was disabled | Denied on next protected request after current DB state check |
| Role removed while token still valid | Denied by current membership-role lookup |
| Cross-school Course/Class/Assessment/Attempt FK is submitted | Database rejects |
| Browser fabricates actor ID, role, score, school_id or audit state | Ignored/rejected; values derived from verified identity and database |
| R2 URL requested for unrelated Course/object key | Worker denies; key is not treated as authorization |
| Direct Supabase Lesson CRUD without Teacher assignment | RLS denies |
| Concurrent autosave races with submit | RPC serialization yields save-before-submit or explicit submitted rejection |

These tests run against PostgreSQL with RLS enabled and representative authenticated roles, plus Worker/API tests. A route-guard or mocked policy-only test does not satisfy the security gate.
