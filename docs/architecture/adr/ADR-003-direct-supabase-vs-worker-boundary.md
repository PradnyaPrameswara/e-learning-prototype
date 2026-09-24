# ADR-003: Keep RLS-Safe Data Paths Direct and Use the Worker for Trusted Workflows

## Status
Accepted

## Date
2026-09-24

## Context
Routing every query through a backend duplicates access paths and adds latency and Worker usage. Sending every multi-step mutation as independent browser-to-Supabase calls cannot guarantee atomicity, protect privileged credentials or consistently enforce sensitive Assessment transitions. PostgreSQL RLS is mandatory in either case.

## Decision
Allow direct browser access only to operations for which database grants, RLS predicates and safe projections fully express authorization and whose allow/deny behavior is tested. Initial allowed examples are own safe profile reads; Student enrolled-Course, published-Lesson, eligible published-Assessment, own Attempt and released-result reads; Teacher assigned-Course reads; scoped Admin reads; assigned-Teacher Lesson draft CRUD; and Teacher Assessment draft CRUD. Assessment draft CRUD including answer-key rows may be direct only under explicit Teacher assignment policies, with no Student grant. Readiness validation and preview use safe projections and do not publish. Lesson publish, unpublish and archive are Worker-only because this implementation writes the required audit event atomically with each lifecycle transition; see [ADR-007](ADR-007-lesson-editing-and-publication.md).

Route privileged, sensitive or race-sensitive operations through the TypeScript Worker and one narrow transaction/RPC: academic structure mutations, school membership/account administration, Teacher assignment, Student enrollment, Assessment publication, assigned-Teacher published-key review, Attempt start, answer autosave, final submission/objective grading, manual grade commit, result release, correction/regrade/re-release, audit writes and R2 authorization.

The exact operation/actor/policy matrix is maintained in [Authorization](../AUTHORIZATION.md). No direct operation is allowed merely because a frontend route hides it. If an RLS policy cannot fully express and test the boundary, use the Worker.

## Alternatives considered

### Proxy all data through the Worker
Rejected as the default because it duplicates safe RLS paths and consumes extra requests. Use only where trusted orchestration is needed.

### Direct browser access for all database operations
Rejected because multi-record state transitions, grading, protected keys and privileged operations need a trusted atomic boundary.

### Client-side authorization plus RLS only on selected tables
Rejected because frontend controls are not security and every exposed table must be protected.

## Consequences
- A direct query requires explicit grants, RLS policy, safe selected columns/projection and positive plus negative tests.
- Protected answer keys, audit insertion and grade writes have no browser path.
- The Worker rechecks current user/school/role/resource context; database RPCs recheck transactional state to close races.
- Database RPCs are narrow typed domain operations, not a generic SQL interface.
- Frontend code may use Supabase clients for reads without making Supabase the owner of presentation workflows.

## Revisit triggers
Revisit an operation if RLS cannot prove its full ownership/role/lifecycle boundary, query shape exposes sensitive fields, policy tests become unreliable, or observed latency/quotas materially change. Revise the matrix and security tests before changing data access.
