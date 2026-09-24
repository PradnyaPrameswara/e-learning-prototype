# Planning Contract

**Status:** Active planning source of truth.

**Review date:** 2026-09-24.

**Implementation status:** This document records intended behavior and architecture. It is not evidence that any product feature or architecture has been implemented.

This contract consolidates GitHub planning issues #1–#16 and the three earlier exploratory planning documents. Issues #1–#16 are closed historical references; future implementation issues are derived from this contract. Their closure recorded planning consolidation, not product implementation or requirement removal. This file remains the active source of truth and is preserved as architecture documentation is added.

The active architecture is the confirmed free-first decision `KEEP_TYPESCRIPT_WORKER_FOR_FREE_TIER`. Laravel was evaluated as an alternative; the later strict-free feasibility decision selected the Worker architecture. Laravel is deferred, is not the MVP backend, and must not be retained as a second business-logic service. The core Worker/Supabase direction in #1, #2, and #13 remains aligned. The point-value ambiguity in #11 is explicitly resolved below: every gradable MVP Question has points greater than zero.

## 1. Contract Status

- This is the local consolidated planning baseline for the clean rebuild.
- It records product scope, architecture boundaries, Assessment integrity, pilot evidence, delivery sequence, risks, and deferred scope.
- It supersedes issues #1–#16 as the active planning baseline after requirements are mapped in the traceability appendix. It does not rewrite historical issue bodies.
- Issues #1–#16 have been closed with comments explaining consolidation; they remain historical references and do not represent completed product features.
- Architecture and product requirements remain change-controlled. Material changes require an updated contract and an ADR before implementation.
- The Phase A architecture specification in `docs/architecture/` resolves architecture-level blockers recorded below; future issues must preserve both documents.

## 2. Product Definition

Build a **school-scoped Learning Management System (LMS) with structured learning content and first-class Assessment integrity**. The product principle is:

```text
Manage → Teach → Learn → Assess → Review → Correct
```

The product manages course participation, lessons, academic Assessments, Student Attempts, grading, feedback, controlled result release, and transparent correction. Content authoring and academic administration support that learning loop; they are not separate general-purpose products.

## 3. Product Scope

The pilot includes only the capabilities needed to deliver the core school learning loop.

### Admin

- School settings and school-scoped identity/profile administration.
- Academic years, classes, subjects, and Courses.
- Teacher and Student management; Teacher-to-Course assignment; Student enrollment/unenrollment.
- Account disable/reactivation where authorized, with required audit history.
- School-scoped audit history for required administrative and academic actions.
- Import/export is a future need to assess when roster size and pilot operations justify it; bulk import/export is not a pilot prerequisite.

### Teacher

- Dashboard scoped to assigned Courses.
- Lesson create/edit/reorder/preview/publish/archive and structured content editor.
- Lesson blocks: heading, paragraph, image, PDF/attachment, external video embed, formula, callout, and Assessment reference.
- Assessment draft/settings, Question authoring, readiness validation, Student-style preview, and immutable publication/version history.
- Submission review, objective-grading status, manual grading for subjective Questions, feedback, result release, correction/regrade, and explicit result re-release.

### Student

- Dashboard and enrolled Courses; published Lessons and learning content; basic profile.
- Assessment availability, Attempt start and resume, answer autosave, unanswered review, final submission, and released score/feedback view.
- Student views expose only the Student-safe Assessment projection and the Student's own Attempts/results.

### Shared/system

- Supabase Auth; school-, role-, assignment-, and enrollment-scoped authorization; PostgreSQL RLS; trusted Worker checks.
- Private Cloudflare R2 files with authorized upload/download; PostgreSQL file metadata and ownership.
- Durable audit events, validation, accessible critical flows, performance measurement, error handling, security testing, observability, and reproducible deployment.
- Notifications are not required for MVP. Add delivery only when a defined workflow needs it and its cost/operations are accepted.

## 4. Non-Goals

The product is not a general school CMS, SIS, ERP, public school website CMS, generic form builder, or standalone examination system. MVP does not include broad attendance/timetable/fee administration, report cards/transcripts, parent/guardian accounts, native mobile applications, chat/forums, video conferencing, AI question generation or grading, plagiarism detection, proctoring, timers, adaptive assessments, random Question pools, shared Question-bank marketplace, SCORM, certificates, gamification, SIAKAD integrations, multi-school SaaS billing/onboarding/custom domains, multi-region infrastructure, microservices, Kubernetes, or large hosted video files. Do not add these solely because they are common in commercial LMS products.

## 5. Final Free-Tier Architecture

The active baseline is:

```text
Astro applications (Student / Teacher / Admin)
             ↓
Supabase Auth + Supabase PostgreSQL / RLS
             ↕
TypeScript Cloudflare Worker for trusted operations
             ↓
Private Cloudflare R2 for application files
```

Use Astro + React + TypeScript for the three web apps; a TypeScript Cloudflare Worker in `apps/worker`; Supabase Auth and PostgreSQL with mandatory RLS; Cloudflare R2; pnpm workspaces; and Turborepo. The Worker is a narrow trusted API/orchestration boundary, not a proxy for every database request.

Do not use Laravel, Go, Rust, Redis, Kafka, Kubernetes, microservices, or a second business-logic backend for MVP. Laravel was evaluated as an alternative; current free-tier evidence did not establish a qualifying, reliable, strict-free PHP host for this pilot. Reconsider Laravel only if paid hosting becomes acceptable or measured domain/operational complexity materially exceeds the Worker model. A change requires a new ADR and planning-contract update before implementation.

## 6. Monorepo Structure

Target structure:

```text
apps/
  student/       # Astro + React, Student experience
  teacher/       # Astro + React, Teacher experience
  admin/         # Astro + React, school administration
  worker/        # TypeScript Cloudflare Worker, trusted operations

packages/
  ui/            # shared non-Radix shadcn/ui components
  schemas/       # shared Zod contracts and runtime validation
  database/      # generated database types and typed DB access helpers
  auth/          # shared auth/session integration helpers, no app UI
  domain/        # shared pure domain rules/types where genuinely shared
  config/        # shared TypeScript/lint/build configuration

supabase/        # local configuration, SQL migrations, seed/test support
docs/
```

pnpm workspaces and Turborepo coordinate JavaScript/TypeScript apps and packages. This layout is a boundary, not a requirement to create empty packages prematurely; create each package when it has a named owner and real shared responsibility.

Package ownership and dependency rules:

- `packages/ui`: shared presentation primitives/components only; no Student/Teacher/Admin rules.
- `packages/schemas`: Zod schemas for validated cross-boundary inputs and outputs.
- `packages/database`: generated PostgreSQL types and narrowly typed database access helpers; schema migrations remain in `supabase/migrations/`.
- `packages/auth`: reusable Supabase Auth/session integration helpers; no app-specific role UI.
- `packages/domain`: pure, genuinely shared academic invariants and value logic; keep transport, database, and UI concerns at their boundaries.
- `packages/config`: shared tooling configuration.
- Apps may depend on shared packages. Packages never depend on apps; apps never import another app. Avoid circular dependencies and generic `packages/utils`/`packages/common` dumping grounds.

Root workflows should include `pnpm dev`, `pnpm build`, `pnpm lint`, `pnpm typecheck`, `pnpm test`, and a documented constraint check (for example `pnpm check:constraints`). CI/review gates detect first-party `useEffect`, `@radix-ui/*`, and disallowed general-purpose form packages before feature work proceeds. Foundation work does not implement product features.

## 7. Frontend Contract

- Astro is the primary framework, routing, and rendering foundation. Keep read-oriented/content-oriented screens Astro-first with server rendering or static rendering where appropriate.
- Use React islands for genuinely interactive workflows such as Lesson/Assessment/Question editors, Attempt answering/autosave, manual grading, correction/regrade screens, and complex Admin interactions. Do not make three full client-side SPAs by default.
- First-party source uses TypeScript and Tailwind CSS 4. TanStack Form is standard for interactive React forms; Zod is the shared runtime validation layer. Simple native/Astro/server forms stay native when client-side form state adds no value. Do not add React Hook Form or Formik.
- Shared shadcn/ui components have one source in `packages/ui`; they contain no role-specific business rules. Do not add or directly import `@radix-ui/*`. Use the approved non-Radix component path and verify accessibility per component.
- First-party React code must not directly use `useEffect`. Prefer Astro/server loading, derived render state, event handlers, TanStack Form, explicit server-state tools only where justified, callback refs, and supported library/framework subscriptions or lifecycle APIs. Do not hide equivalent effect behavior in a custom hook. A genuine integration exception requires a narrow ADR before code.
- Frontend validation and role guards improve UX; the Worker, Auth, RLS, and database remain authoritative.

## 8. Backend Contract

`apps/worker` uses TypeScript for MVP and Cloudflare Workers runtime/bindings. Keep request handlers thin: authenticate, authorize, validate, call domain rules, invoke narrow transactional database operations, and map responses. Avoid duplicating domain rules in each route or app.

Use shared TypeScript/Zod contracts where they cross app/Worker boundaries. Enforce durable invariants in PostgreSQL constraints/RLS and trusted database transactions/RPCs where appropriate. Never expose service-role credentials, database credentials, or permanent R2 credentials to the browser. A separate Go/Rust service is not justified without measured CPU, batch, reporting, or operational workload.

## 9. Authentication & Authorization

Active identity/security model:

```text
Supabase Auth authenticates
+ PostgreSQL RLS protects user-scoped database access
+ trusted Worker checks authorize privileged and transactional operations
```

Supabase Auth is the sole authentication authority. Database memberships/roles are protected data, not user-editable profile fields. Validate Supabase sessions/JWTs in the app/server integration. Frontend role checks are presentation controls only.

Authorization is school scoped and role specific:

- Student: own profile and Attempts; Courses/resources only through current enrollment.
- Teacher: assigned Courses and associated Lessons, Assessments, submissions, grading, and results.
- Admin: authorized administration within the applicable school. Admin does not implicitly become a Teacher.
- Resource IDs are never proof of access. Every request checks actor, role, school, and relevant enrollment/assignment/ownership.

The first pilot may use one school, but every protected record must carry an unambiguous `school_id` or an enforceable parent relationship. Parent-child links must not permit cross-school mismatch. Design for future school isolation without building SaaS billing, tenant self-service, or complex tenant operations now.

## 10. Direct Supabase vs Worker Boundary

Do not send every request through the Worker. The architecture specification must validate the exact RLS policy and operation matrix before foundation implementation.

### Direct Supabase + RLS

Appropriate only for safe user-scoped reads/writes whose authorization is fully expressible and tested in RLS, such as own safe profile access, Student enrolled-Course/published-Lesson reads, assigned Teacher safe Course reads, and ordinary scoped Lesson draft CRUD if the policy is complete. Student reads use explicit safe projections; drafts and answer keys are never exposed. Direct paths require automated allow/deny and cross-school tests.

### Trusted Worker

At minimum route privileged Auth/account administration, Assessment readiness/publication and immutable version creation, Attempt creation where multi-record eligibility checks are needed, canonical final submission and trusted objective grading, privileged manual-grade commits, result release/re-release, correction/regrade, sensitive audit actions, and R2 upload/download authorization through the Worker. Future bulk operations also use a trusted path.

For an atomic multi-record change, use the Worker with a narrow PostgreSQL transaction/RPC or equivalent atomic database operation. Do not sequence unrelated API requests and treat them as a transaction. Any privileged credential that bypasses RLS requires complete server-side actor/ownership checks; RLS remains mandatory for direct user access and a defense layer for protected tables.

## 11. Database Contract

Supabase PostgreSQL is the single relational source of truth for schools, memberships/profiles, academic years, classes, subjects, Courses, assignments/enrollments, Lessons/content, Assessment drafts and published versions, Questions/options/protected keys, Attempts/answers, grades/results, correction/regrade history, file metadata, and audit events.

- Use PostgreSQL foreign keys, constraints, indexes, and transactions for ownership, referential integrity, state transitions, idempotency, and query patterns.
- `supabase/migrations/` is the sole authoritative schema migration history. Every schema, RLS, function, and policy change is version-controlled and reviewed; do not make an untracked production dashboard change.
- Generate TypeScript database types from the migrated schema and keep generation reproducible. Shared Zod API/domain contracts are not a replacement for DB types.
- Use narrowly scoped PostgreSQL functions/RPCs when a Worker operation needs atomic mutation across multiple records. Keep security checks explicit and test transactions against PostgreSQL behavior.
- Use Supabase Free for development and initial pilot validation within current published limits. It is not a production SLA or automatic backup guarantee. Current planning evidence records shared Nano compute, a 500 MB database, connection/pooler limits, possible inactivity pause, and no managed automatic backup; re-verify provider limits before deployment.
- Demonstrate a tested backup/restore procedure before real graded pilot use. Measure the deployed configuration; 100 concurrent Attempts are a test profile, not a capacity claim.

## 12. Storage Contract

Use private Cloudflare R2 for Lesson images, Question images, PDFs, and supported attachments. PostgreSQL stores object key, school/course/resource ownership, MIME/size metadata, and lifecycle state—not binary content. Keep objects private; validate actor, school, course/resource context, MIME type, and configured size. Use short-lived authorized upload/download URLs where appropriate. Permanent R2 credentials stay server-only. Use external video embeds rather than large hosted video files.

Planning evidence records an R2 Standard free allowance of approximately 10 GB-month storage, 1 million Class A operations, 10 million Class B operations, and no egress charge for the listed R2 Standard path. Treat quotas, payment-method requirements, and overage terms as changeable; re-check before pilot deployment and monitor usage.

## 13. Assessment Domain

Assessment is an academic domain with scoring, identity, history, publication, Attempts, grading, and controlled disclosure—not a generic form builder.

Lifecycle:

```text
DRAFT
  → readiness validation (READY_FOR_REVIEW may be computed)
  → Student-style preview
  → publish immutable version
  → CLOSED
  → ARCHIVED
```

Publication is a trusted, atomic transition. One transaction creates/activates the immutable version and its Question, option, scoring, protected answer-key, and audit snapshots, or leaves no partial publication behind. It validates required title/instructions, non-empty Questions, type-specific configuration, valid protected objective answers, positive point values for every gradable Question, option/media references, consistent total points, and valid enabled availability settings. Failures identify the setting or Question. Teacher preview should use the Student-facing read model closely and must not disclose correct answers.

Published versions, Questions, options, scoring basis, and protected answer keys are immutable academic history. Keep editable drafts separate from published snapshots. Attempts permanently bind to one exact published version and stable Question/option identities. Later Teacher edits create a new draft/version; never update historical versions in place. Closing/archiving preserves Attempts, answers, grades, corrections, and audit records.

MVP Question types: Multiple Choice, Multiple Select, True/False, Short Answer, Paragraph/Essay, and Numeric. Options use a flexible relational/collection representation, never fixed `option_a`/`option_b` columns. Support text/formulas and authorized Question images. Every gradable Question must have `points > 0`; non-graded instructional material belongs in Lesson content. Total points are derived consistently from Question points.

MVP delivery policy is one final Attempt per Student per Assessment policy. No timer, proctoring, adaptive Questions, or randomized pools. Availability and due dates are optional only if semantics are consistent and server-time based.

## 14. Attempt / Autosave / Concurrency Contract

Attempt lifecycle:

```text
IN_PROGRESS → SUBMITTED → GRADED
```

An authorized enrolled Student starts an eligible published Assessment; the Attempt permanently records the exact version. Draft, closed, archived, non-enrolled, or otherwise ineligible work is denied according to documented availability policy. Refresh/reopen resumes the same in-progress Attempt. Student writes are forbidden after submission.

### Autosave

- Under the agreed healthy-network test profile, a meaningful changed answer must reach durable server storage within 5 seconds.
- Debounce/coalesce changes; do not issue one request per keystroke.
- A `Saved` acknowledgement means the durable server/database write succeeded. Local state alone is never reported as saved.
- UI distinguishes `Saving`, `Saved`, `Sync failed/retrying`, and `Offline/pending sync`. Unsynced edits remain visibly pending and recoverable where the chosen client buffer permits.
- Autosave does not block navigation/answering. The server remains authoritative after reconnection.

### Multi-tab concurrency

Use deterministic answer revision / compare-and-set semantics. Example: a write with expected revision 7 succeeds and advances to 8; another stale write still expecting 7 is rejected as a conflict. Do not silently apply last-write-wins to stale payloads. Surface the conflict and keep the local unsynced value visible for deliberate refresh/reconciliation. When another tab submits, reject all later writes and tell stale tabs the Attempt was submitted elsewhere.

### Final submission

Double-clicks, concurrent tabs, retries, and timeouts must yield exactly one canonical `SUBMITTED` transition, one canonical `submitted_at`, one grading execution, and no post-submit Student mutation. Implement with a justified combination of transaction/conditional state transition, database constraints, and idempotency identity as needed. Retries return the canonical submission result rather than creating another submission or grade. Do not claim submit success while required unsynced changes are unresolved.

## 15. Grading

The trusted backend/database is authoritative; client calculations are display-only.

- Automatic grading: Multiple Choice, Multiple Select, True/False, and Numeric exact match.
- Manual grading: Short Answer and Paragraph/Essay, with per-answer score and feedback where required.
- MVP Multiple Select is all-or-nothing. Partial credit requires an explicit later product decision.
- Numeric exact match requires a deterministic normalized representation. No unit conversion, floating tolerance, or formula evaluation is implied.
- Grading and regrade are retry-safe and cannot execute twice because of request retries. Manual grades remain separate and are preserved by automatic regrade unless an authorized explicit override occurs.
- Teacher access to submissions is assigned-Course scoped. Totals and per-question scores remain consistent with points.

## 16. Result Release

Results remain hidden until an authorized Teacher explicitly releases them. The default Student disclosure is score and Teacher feedback. Correct-answer data is not disclosed automatically; any later answer-key disclosure needs an explicit product policy. Release and re-release are durable audited actions. If correction/regrade changes an already released result, it enters review-required behavior until a Teacher reviews and explicitly re-releases it; no silent Student grade changes.

## 17. Correction / Regrade

Never mutate the original published Assessment version or its Question/key history. Create a correction against the published version and affected Question(s), preserving actor, reason, original interpretation, corrected interpretation, affected Attempts/results, timestamp, and score deltas or durable references to them.

Regrade only affected scoring paths, is retry-safe, and preserves manual grades unless there is an explicit authorized override. A not-yet-released result can be corrected before release. A changed already-released result must become `REVIEW_REQUIRED` (or equivalent), require Teacher review, and be explicitly re-released. Keep the before/after grade history and correction/regrade audit durable so a regrade cannot silently rewrite the historical Assessment or result.

## 18. Audit

Audit is durable, school scoped, and sufficient to answer who did what to which target, when, why, and which academic results changed. Store minimal before/after summaries and references; do not copy full sensitive payloads into logs.

Required auditable actions:

```text
assessment.publish
assessment.correction.create
assessment.regrade
grade.manual_change
grade.override
result.release
result.rerelease
user.disable
teacher.assign
student.enroll
student.unenroll
```

Include event ID, `school_id`, actor ID/role, action, target type/ID, minimal before/after summaries, required reason for corrections/overrides, timestamp, and request/session context where useful. Write audit events explicitly within the responsible trusted action/transaction so a failed action cannot leave a false audit entry and a committed sensitive action cannot silently omit its audit record. Avoid relying solely on generic listeners for critical history.

## 19. Free-Tier Constraints

The active strategy is Cloudflare Pages/Workers + Supabase Free/Auth/RLS + private R2, bounded by actual current allowances. Free tier is a deployment constraint, not an SLA.

- Supabase Free planning limits include shared Nano compute, a 500 MB database, connection/pooler limits, possible inactivity pause, and no managed automatic backup. Verify limits/connection behavior at deployment; provide and drill a backup/restore procedure before real grading.
- Cloudflare Workers Free planning limits are approximately 100,000 requests/day and 10 ms CPU per invocation. Re-verify immediately before deployment and measure CPU-heavy rendering/grading. Network wait is not Worker CPU, but this does not prove the complete database path will meet latency targets.
- R2 uses private Standard storage and its published free allowances only; monitor storage/operation usage and confirm current terms.
- Static Astro pages are preferred where appropriate. SSR/dynamic Pages Functions consume applicable Worker quotas and must be included in usage/load budgets.
- Supabase Free and other free providers can pause, impose shared-resource limits, lack SLA/managed backup, or change allowances. Never label the system pilot-safe until the deployed stack passes load, reliability, restore, and security checks.
- Recheck exact provider limits and payment/overage requirements before deployment. A free quota does not imply guaranteed availability or cost-free overage.

## 20. Pilot Requirements

Initial real pilot target: 1 school, 1 real class, 1 Teacher, 20+ Students, at least one complete Lesson/Assessment cycle, and a complete Admin → Teacher → Student → grading → result-release workflow without developer intervention or direct database patching.

Separately validate the #16 load profile: 100 concurrent active Assessment Attempts, representative debounced autosave traffic, and a final-submit burst. This is the minimum validation profile, not a maximum-capacity claim and not the expected initial class size.

Before real Student grading, require immutable publication and exact Attempt/version binding; protected answer keys; durable autosave/recovery; deterministic stale-write/multi-tab behavior; canonical idempotent submission; trusted objective and manual grading; controlled release; correction/regrade and re-release; audit; negative authorization/RLS tests; mobile Student flow; a backup/restore drill; and measured deployed-stack evidence. Do not make pilot claims from local development or an untested provider quota.

## 21. Measurable NFRs

Validation targets from #16:

- Student Lesson/Assessment route LCP target `≤ 2.5 s` under a documented production-build mobile/constrained-network profile.
- Critical Student interaction latency target `≤ 200 ms` where measurable with the chosen tooling.
- Durable answer persistence `≤ 5 s` under the agreed healthy-network test profile.
- No confirmed duplicate final submission, unauthorized leakage, data corruption, or platform-caused answer loss in reliability/load validation.
- Pilot success: at least 95% of started Attempts reach an understood valid final state with no confirmed platform-caused answer loss; 100% of released grade changes/corrections attributable to authorized actors; Teacher/Admin workflows complete without developer/database intervention; Student flow validated on mobile.
- Critical Student, Teacher, and Admin flows have no known blocking keyboard, labeling, focus, or contrast defects.

These are validation targets, not public SLA or capacity promises. Keep reproducible load/performance profiles, E2E/race/security results, known exceptions, restore evidence, and pilot feedback. Convert blocking findings into focused issues before wider rollout.

Required validation coverage includes PostgreSQL/RLS allow-and-deny tests for school, role, Teacher assignment, Student enrollment, cross-Course access, protected answer keys, immutable versions, and Attempt state transitions; transaction/race tests for stale writes, multi-tab submission, double-submit/network retry, post-submit writes, duplicate grading, and retry-safe regrade; and critical Playwright paths for Admin academic setup/assignment/enrollment, Teacher Lesson and Assessment authoring/publication, Student Attempt/autosave/submit, grading/release, Student result view, and correction/regrade/re-release. Include mobile Student flow, upload authorization/type/size checks, performance/load evidence, and restore drill in release evidence.

## 22. Development Phases

### Phase A — Engineering Foundation

Finalize architecture specification/ERD/authorization and Assessment integrity boundaries; lock #13 constraints; establish pnpm/Turborepo foundation, migrations/type generation, CI constraint checks, and deployment conventions. Architecture deliverables belong under `docs/architecture/` and should cover system architecture, ERD, authorization, frontend boundaries, Assessment integrity, and ADRs for material decisions. No real-school pilot or product-feature claim in this phase.

### Phase B — Internal Product Validation

Validate identity and academic structure, Course management, Lesson authoring/delivery, and Assessment drafts/Questions using internal or synthetic data. This can validate workflow and terminology but is not safe for real graded Student work until Phase C integrity guarantees are complete.

### Phase C — Pilot-Safe MVP

Complete immutable readiness-validated publication, Student Attempt/version binding, autosave/resume/concurrency/idempotent submission, objective and manual grading, feedback, controlled result release, correction/regrade/audit/re-release. Run the real small-school workflow and the separate 100-Attempt validation profile.

### Phase D — Production / Operational Hardening

Complete deployment security review, accessibility/performance/load evidence, backup/restore, observability/error handling, sensitive-route rate limits, runbooks, and pilot feedback loop. Feature-complete does not mean operationally ready.

## 23. Development Order

Use this dependency order, expressed as contract stages rather than relying on closed issue numbers:

```text
Planning Contract review
  → architecture specification / ERD / security and Assessment decisions
  → Turborepo and CI foundation
  → identity, school, roles, academic structure, assignments/enrollments
  → Lesson + Assessment draft foundations
  → Question authoring and scoring/media
  → readiness, Student preview, immutable publication
  → Attempt creation, autosave/resume, concurrency and submission reliability
  → objective/manual grading, feedback and result release
  → correction/regrade and grade history/re-release
  → hardening, load/reliability evidence, restore drill and pilot
```

Break large epics into focused implementation issues before coding. Keep independently reviewable work (for example Lesson editor vs R2 upload, publication vs Attempt reliability, automatic vs manual grading) in separate coherent changes.

## 24. Git Workflow Contract

- One coherent issue/change per dedicated branch; use a clear name such as `feat/<issue>-short-scope`, `fix/<issue>-short-scope`, or `docs/<issue>-short-scope`.
- Do not present unfinished implementation as a completed feature. No final PR until acceptance criteria and relevant validation pass.
- No automatic merge; never merge on behalf of the user. Later independent work may proceed on another branch while earlier work waits for review if dependencies allow.
- Keep unrelated refactors out of feature PRs. Reference the focused implementation issue in each PR.
- Architecture changes require an ADR and planning-contract revision before implementation; do not silently change a locked constraint.
- Never commit secrets. Database migrations and RLS changes are reviewed and version controlled.

## 25. Legacy Code Rule

`E-learning-Fisika` is reference-only for useful product behavior and user flows. This repository is a clean rebuild. Never copy legacy source, Firebase implementation, Firestore schema, components, utilities/helpers, routes/API architecture, compatibility layers, shims, or fallback/dead code. There is no legacy compatibility requirement unless a future explicit decision introduces one.

## 26. Architecture Change Procedure

The free-tier TypeScript Worker architecture is the active baseline. If later evidence supports Laravel, Go/Rust, another storage/auth model, or paid hosting, stop before implementing the change; record workload/economic evidence and trade-offs in an ADR, identify affected contract and implementation issues, revise the contract and approved architecture source, then create focused work. Do not add a second business-logic backend while transitioning. Recheck provider quotas immediately before deployment.

Reconsider backend evolution only when paid hosting is acceptable or measured needs (for example large imports/reports/regrades, substantial scheduled processing, analytics, or complex notifications) exceed the Worker model. Redis, queues, microservices, or additional runtimes require demonstrated need.

## 27. Open Risks

- Free-tier allowances, pauses, payment/overage terms, and provider policies can change. Current free-tier research is not a service guarantee.
- Supabase Free shared compute, connection/pooler limits, no managed automatic backup, and inactivity pause may prevent pilot targets even if application traffic remains within its quota.
- The separate 100-concurrent-Attempt profile, debounced autosave, and submit burst are unverified until run against the deployed target. No capacity claim is made in advance.
- Worker 10 ms CPU may constrain CPU-heavy work; measure grading/rendering in a production build. If work outgrows the bound, revisit only with evidence and a planning/ADR change.
- Free hosting/storage does not replace restore testing, observability, security controls, accessibility checks, or incident handling.

### OPEN_DECISIONS

Do not weaken settled product invariants. There are no remaining architecture-level blockers for foundation work. The accepted Phase A decisions are specified in [System Architecture](../architecture/SYSTEM_ARCHITECTURE.md), [ERD](../architecture/ERD.md), [Authorization](../architecture/AUTHORIZATION.md), [Frontend Architecture](../architecture/FRONTEND_ARCHITECTURE.md), and [Assessment Integrity](../architecture/ASSESSMENT_INTEGRITY.md), and recorded in ADR-001 through ADR-005.

The architecture issue resolves the system/package/deployment boundaries, logical ERD and school ownership, sole Supabase Auth trust model, RLS rules and denial matrix, direct Supabase versus Worker boundary, trusted transaction/RPC operations, immutable publication and active-Attempt behavior, availability/due/close/archive semantics, answer compare-and-set, idempotent submission, grading/release/correction/regrade history, R2 authorization, and baseline observability/health/quota constraints. Material changes require an ADR and contract revision before implementation.

**Implementation decisions to settle before the affected workflow ships (not architecture blockers):**

- Exact answer revision field/API names, conflict response serialization and stale-tab reconciliation UX; the answer-level compare-and-set invariant is settled.
- Optional request/write identity for tracing response-loss retries; database state, conditional transition and uniqueness are the idempotency authority, with no separate general idempotency service required for MVP.
- Numeric parser test vectors and boundary handling for the accepted plain-decimal normalization; no tolerance, units, locale conversion, exponent notation or formula evaluation is implied.
- Persisted names/transitions for review-required/re-released result states.
- Exact Question/option/media schemas and type-specific required/optional behavior.
- R2 MIME allowlist, maximum sizes, URL TTL, and exact orphan-cleanup configuration; the trust boundary and server-generated key pattern are settled.
- Account invitation/provisioning and password-recovery/email delivery details; Supabase Auth remains the authority.
- Specific accessible non-Radix primitive for a component when that component is selected.
- Concrete production domains, environment secrets, migration execution/rollback workflow (with Supabase migrations as the sole schema source), and quota alert thresholds.
- Query-plan-driven index tuning and final load/performance thresholds after the documented profiles are executed.

**Post-MVP:**

- Roster import/export and formats; notification delivery/channel; large reports, analytics, large regrade batching, media processing, and scheduled jobs.
- Whether new correct-answer disclosure, partial-credit Multiple Select, multiple Attempts, timers, or other Assessment policy expansion is needed.
- Any paid-tier or alternate backend decision after deployment and workload evidence exists.

## 28. Deferred / Post-MVP Scope

Deferred, not implicit requirements: native mobile app; chat/forum/video conferencing; AI-generated Questions/AI grading/plagiarism detection; timers/proctoring/adaptive/randomized Assessments; shared Question banks; parent accounts; gamification/certificates/SCORM/SIAKAD; enterprise report cards/transcripts; large video hosting; multi-school SaaS provisioning/billing/custom domains; multi-region or microservices/Kubernetes; advanced analytics; imports/exports, broad notification service, and large background processing. Small bounded pilot grading/release/regrade remains synchronous unless measurement shows a reliable need for queued work. No MVP queue or always-running scheduler is required.

## 29. Final Architecture Summary

```text
ACTIVE_PRODUCT_DIRECTION: School-scoped LMS with first-class Assessment integrity
FRONTEND: Astro + React + TypeScript; Tailwind CSS 4; TanStack Form; Zod; non-Radix shadcn/ui
BACKEND: TypeScript Cloudflare Worker
AUTH: Supabase Auth
AUTHORIZATION: PostgreSQL RLS + trusted Worker checks
DATABASE: Supabase PostgreSQL Free for development/pilot validation
STORAGE: Private Cloudflare R2
MONOREPO: pnpm workspaces + Turborepo
ASSESSMENT_MODEL: immutable published versions; every Attempt bound to exact version
FREE_TIER_STRATEGY: Cloudflare Pages/Workers + Supabase Free + R2 within verified allowances
LARAVEL_STATUS: evaluated alternative; deferred while strict free-tier is a primary constraint
QUEUE_REQUIRED: NO for MVP
SCHEDULER_REQUIRED: NO for MVP
```

## Archived GitHub Planning Traceability

Every issue in the verified planning set #1–#16 was open at consolidation review. The purpose and requirements remain represented below. “Deferred” identifies scope intentionally outside the pilot; it does not imply that core requirements in the original issue were discarded.

| Issue | Original purpose | Contract sections superseding it | Requirement intentionally deferred |
|---|---|---|---|
| [#1 — PRD / E-Learning Platform MVP v1.1](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/1) | Product source of truth, end-to-end workflow, success measures, phases, scope and roles. | 1–29; especially 2–4, 13–23. | Explicit MVP non-goals in 4 and 28; no core PRD workflow is dropped. |
| [#2 — Architecture, data model and security boundaries](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/2) | Define app/data boundaries, ERD, identity/RLS/Worker split, school ownership, Assessment integrity, concurrency, audit, R2 and ADRs. | 5–12, 13–19, 26–27. | SaaS billing/tenant operations and enterprise/multi-region design; implementation choices remain in `OPEN_DECISIONS`. |
| [#3 — pnpm + Turborepo foundation](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/3) | Bootstrap apps/packages, shared tooling, CI/root workflows, constraint checks and Supabase migration structure. | 6–8, 11, 23–26. | Product features and production deployment are not foundation work. |
| [#4 — Identity, roles and academic structure](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/4) | Supabase Auth, profiles/roles/membership, school/year/class/subject/Course, assignment/enrollment, Admin flows and RLS tests. | 3, 9–11, 20, 22–23. | Advanced roster import/export and broad school operations. |
| [#5 — Lesson authoring and content delivery](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/5) | Assigned-Course Lesson CRUD, structured ordered blocks, preview/publication, safe Student reading, R2 upload and mobile rendering. | 3, 7, 12, 20, 23. | Assignment submission and large hosted video; use external embeds. |
| [#6 — Assessment authoring, publication and integrity epic](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/6) | Purpose-built LMS Assessment authoring, readiness, preview, immutable publication, Attempts/grading/release boundaries. | 3, 13–19, 23. | Question bank sharing, adaptive/random, timed/proctored exams, AI authoring/grading, plagiarism and analytics. |
| [#7 — Student Attempts, autosave and submission integrity](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/7) | Eligible Attempt start/resume, version binding, protected read model, autosave, unanswered review and canonical submit. | 13–16, 20–23. | More than one final Attempt, timers, proctoring, randomized papers, grading UI in the Attempt scope. |
| [#8 — Grading, feedback and controlled result release](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/8) | Trusted objective/manual grading, assigned-Course review, feedback, final scores, release, audit and correction integration. | 15–18, 20, 23. | Advanced weighting/report cards, AI grading, plagiarism and appeals. |
| [#9 — Harden, test and deploy](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/9) | Security, accessibility, performance, reliability, deployment, observability, backup/recovery, E2E and pilot evidence. | 19–23, 27–28. | Enterprise SLA, multi-region, premature infrastructure rewrites, unneeded paid scaling. |
| [#10 — Assessment domain, draft lifecycle and delivery settings](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/10) | Draft metadata/autosave, delivery policy, lifecycle, server validation, trusted availability and historical Attempt preservation. | 13, 20, 27. | Timer/proctoring/random pools; date rules remain optional and exact semantics are open. |
| [#11 — Question authoring, scoring, media and ordering](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/11) | Author supported Question types, content/formula/media, options, trusted answers, scoring, ordering and deterministic edits. | 3, 13, 15, 27. | Question banks/randomization; original non-negative point wording is resolved to `points > 0` for every gradable Question. |
| [#12 — Validate, preview, version and publish Assessments](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/12) | Central readiness validation, Student-style preview, immutable versions, version-bound Attempts, safe revisions and answer protection. | 13, 20, 27; active-Attempt behavior is resolved in `docs/architecture/ASSESSMENT_INTEGRITY.md`. | Advanced banks/adaptive/random/proctoring; Attempt migration or retakes require a future explicit product decision. |
| [#13 — Locked frontend stack and engineering constraints](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/13) | Set non-negotiable Astro/React/TS/Tailwind/TanStack/Zod/shadcn, no Radix/useEffect, no legacy code, monorepo boundaries and CI checks. | 5–8, 23–26. | No constraint is silently relaxed; exceptions follow ADR/change control. |
| [#14 — Autosave, multi-tab concurrency and idempotent submission](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/14) | Durable saves, visible offline/failure, refresh recovery, stale-write conflict, one canonical submit and no duplicate grading/post-submit writes. | 13–14, 20–23. | Collaboration/shared Attempts and multiple independent Attempts. |
| [#15 — Correction, regrade and grade history](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/15) | Auditable correction/regrade of immutable publication; protect manual grades; score deltas; review and explicit re-release. | 16–18, 20, 23. | Appeals, broad weighting, AI regrading, full notification service. |
| [#16 — Measurable NFRs, load profile and pilot success](https://github.com/PradnyaPrameswara/e-learning-prototype/issues/16) | Define pilot baseline, success criteria, performance/autosave/100-Attempt profile, accessibility, release evidence and feedback. | 19–23, 27. | Enterprise SLA, district capacity certification, multi-region and unrelated features. |

## Planning Baseline Validation

- [x] This contract remains the active planning source of truth.
- [x] TypeScript Cloudflare Worker is active; Laravel is evaluated/deferred, not active.
- [x] Supabase Auth, mandatory PostgreSQL RLS, trusted Worker checks, Supabase PostgreSQL, and Cloudflare R2 are recorded.
- [x] Astro/React/TypeScript frontend and pnpm/Turborepo boundaries are recorded.
- [x] Immutable Assessment publication and exact Attempt-to-version binding are preserved.
- [x] Autosave durability target and deterministic multi-tab stale-write behavior are preserved.
- [x] Final submission is canonical/idempotent with no post-submit mutation or duplicate grading.
- [x] Correction/regrade never rewrites historical published versions; released changes require review and explicit re-release.
- [x] Required audit actions and minimal sensitive summaries are preserved.
- [x] Free-tier constraints and unverified deployment/load risks are explicit.
- [x] Traceability covers every verified issue #1–#16.
- [x] Phase A architecture documentation is the required location for resolved architectural decisions; implementation-level details remain explicitly deferred.
