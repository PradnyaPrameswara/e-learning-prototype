# ADR-005: Use Answer Compare-and-Set and a Canonical Submit Transaction

## Status
Accepted

## Date
2026-09-24

## Context
Autosave can race across tabs, a Student may retry after a lost response, and final submit can race another save or submission. Silent last-write-wins can discard an answer. Multiple submit handling outside the database can duplicate timestamps or grading.

## Decision
Track a monotonic revision per AttemptAnswer. Every accepted answer mutation supplies its expected revision. A narrow Worker/RPC operation verifies current Student ownership and IN_PROGRESS status, serializes against the parent Attempt state and updates only when the expected revision matches. A stale write returns an explicit conflict and never overwrites the newer answer. Browser state displays pending versus server-acknowledged persistence accurately.

Final submission locks the Attempt row or uses an equivalent conditional state transition inside one PostgreSQL transaction. The first valid transition from IN_PROGRESS to SUBMITTED sets one database timestamp, freezes answers, computes objective grading from trusted versioned keys, creates one result/grade state and required audit. Unique constraints on one Attempt per Student/Assessment and one Result per Attempt provide durable idempotency. A retry after a committed submit returns the canonical existing state and does not grade again. A rollback leaves no partial transition.

## Alternatives considered

### Last-write-wins
Rejected because a stale tab can silently overwrite a newer answer.

### Client-generated score or submitted timestamp
Rejected because client state is untrusted and can be modified or replayed.

### Separate asynchronous grading for ordinary objective items
Rejected for the bounded MVP because it creates an unnecessary queue and a window where a submitted Attempt is not consistently graded. Revisit if measured Assessment size or Worker CPU requires it.

### General idempotency service for every request
Not required for this state transition: transactional state, row lock/conditional transition and unique constraints establish one canonical result. Request identifiers may support tracing and optional retry recognition, but are not the integrity authority.

## Consequences
- Autosave must be debounced/coalesced and meet ≤ 5-second durable persistence under the healthy-network test profile.
- Answer-level revisions allow independent question writes to conflict independently; a parent Attempt lock serializes save against submission.
- A conflict UI must refresh/reconcile rather than silently retry stale payloads.
- Database concurrency tests cover two tabs, response loss, double-click, simultaneous submits, save/submit races and post-submit writes.
- Objective grading is synchronous and in the submit transaction for MVP; bounded regrades are retry-safe per Attempt.
- If the Worker CPU or database workload exceeds measured limits, the team may introduce durable chunked processing without weakening the canonical transition.

## Revisit triggers
Revisit the model only if representative measurements show the CAS/transaction design cannot meet the reliability target or workload requires multiple concurrent answer writers at high scale. Any alternative must preserve no lost acknowledged answers, explicit stale conflicts, one submitted timestamp, one grading effect and no post-submit mutation; capture it in an ADR before implementation.
