# Assessment Integrity and Transaction Model

**Status:** Required domain contract for future Assessment implementation issues.

**Source of truth:** [Planning Contract](../planning/PLANNING_CONTRACT.md).

**Assessment is an academic domain, not a generic form builder.**

## 1. Lifecycle and trust boundaries

~~~text
Mutable Draft
  → readiness validation
  → Student-safe preview
  → atomic publication of immutable AssessmentVersion
  → eligible Student starts Attempt bound to that version
  → answer autosave/resume with revision compare-and-set
  → one canonical final submission
  → trusted objective grading
  → Teacher manual grading where needed
  → explicit result release
  → correction event and retry-safe regrade when needed
  → review and explicit re-release if a released result changes
~~~

The browser can edit only mutable draft content or its own in-progress answers through permitted paths. The browser never chooses the authoritative published version, score, submit timestamp, released grade revision, correction outcome or audit actor. RLS applies to direct safe reads; state transitions use the trusted Worker and one narrow PostgreSQL transaction/RPC.

## 2. Draft, readiness, preview and immutable version

An Assessment has a mutable identity and one current mutable draft tree. Readiness is computed from that draft at validation and again inside publication; do not persist a redundant READY state that can drift.

Readiness must reject at least:

- missing/invalid settings, Course ownership or availability window;
- no gradable Questions;
- unsupported Question type or malformed type-specific content;
- any gradable Question with points ≤ 0;
- missing/invalid options or scoring configuration;
- missing protected answer key for objectively graded types;
- invalid versioned media ownership;
- unsupported answer/scoring combinations.

The Student-style preview renders only the Student-safe shape: prompt, ordered options, directions, points and display settings. It never includes answer-key fields or scoring internals in HTML, serialized props, API responses or logs. Preview does not imply that the Assessment is published. A Teacher may inspect a published key only through an explicit Worker review/correction operation scoped to an assigned Course; there is no direct browser read of the protected version-key table.

### Publication transaction

The Worker authenticates the current assigned Teacher and requests one narrowly scoped transaction. The database transaction:

1. locks the Assessment identity/current draft revision;
2. rechecks Course assignment, school ownership, Assessment lifecycle and draft revision;
3. recomputes readiness over the exact draft state being published;
4. allocates the next monotonically increasing version number;
5. inserts AssessmentVersion settings plus immutable ordered Question, option, scoring and protected answer-key snapshots;
6. points current_published_version_id at the inserted version and updates Assessment lifecycle;
7. inserts assessment.publish AuditEvent with actor, target, version, timestamp and safe before/after summary;
8. commits all rows together.

Any validation, insert, pointer, or audit failure rolls back publication. A retry after response loss returns the already-current publication outcome when it represents the same accepted draft revision, or reports that a newer publication exists; it does not create duplicate versions.

A published version and every child snapshot are immutable. Corrections change grading interpretation through a separate correction record; they do not edit the original version, question, option or protected key. An edit after publication changes mutable draft rows. Publishing again creates a new AssessmentVersion.

## 3. Publish while Attempts are active

Publishing a new version is allowed while older Attempts are IN_PROGRESS.

- Attempts already created remain permanently bound to their original AssessmentVersion and continue to use that version's prompts, options, keys and scoring interpretation.
- New eligible Attempts bind to the current published version at the instant the start transaction commits.
- A Student may have only one final Attempt per Assessment under MVP policy. A Student who already started version N cannot start version N+1 for the same Assessment, including after version N is submitted.
- The Teacher UI should show the active Attempt count/version before publication and explain that existing Students remain on the old version.
- If there is a future requirement to migrate/restart active Attempts, it requires an explicit product/ADR decision; it cannot be inferred from republishing.

This is deterministic under concurrent publish/start because both operations lock/check the Assessment state in the database transaction.

## 4. Availability, due time and closure semantics

All availability decisions use trusted database time, not browser clock.

- **available_from:** inclusive earliest time a new Attempt may start.
- **due_at:** latest time a new Attempt may start. At or after due_at, no new Attempt starts. MVP has no timer, auto-submit or automatic penalty rule.
- **An Attempt started before due_at:** remains available for answer save and submission after due_at. The persisted submitted_at records the actual time; a late flag may be derived for Teacher review. MVP applies no automatic score penalty.
- **CLOSED:** prevents all new Attempts immediately, regardless of available_from/due_at, but does not invalidate, erase or forcibly submit existing IN_PROGRESS Attempts. Existing Attempts may finish and submit.
- **ARCHIVED:** read-only historical state. It prevents new starts and authoring/publication. It can be set only when no IN_PROGRESS Attempts remain, unless a future explicit close-out policy is adopted. Historical Attempts, results, corrections and audit remain readable to authorized roles.

These MVP semantics intentionally avoid timer/proctoring behavior and automatic deadline outcomes. If the product later needs hard submission cutoffs, that is a material policy change requiring a new ADR and contract update before implementation.

## 5. Attempt start and version binding

Only the Worker start operation may create an Attempt. In one transaction it:

1. confirms authenticated user has active Student membership and active enrollment matching the Assessment Course class/year;
2. locks/checks Assessment status, availability, current published version and trusted database time;
3. inserts an Attempt with school_id, assessment_id, assessment_version_id and student membership;
4. relies on unique (assessment_id, student_membership_id) and foreign keys to prevent duplicates, wrong-school relations or a version from another Assessment;
5. writes required audit only if product policy requires start audit; Attempt history itself remains durable.

The unique constraint resolves simultaneous starts. A retry for the same Student returns the existing Attempt and its pinned version if appropriate; it never changes the version pointer. Draft or unpublished Assessment rows cannot create an Attempt.

Student read queries may return the Attempt's exact version through a Student-safe projection. RLS ensures the Attempt belongs to the caller and the version belongs to that Attempt. Protected keys are separate and absent from the projection.

## 6. Autosave and deterministic concurrency

The server is the durable source of truth. The client must display Saving, Saved, Sync failed/retrying, or Offline/pending sync and may show Saved only after server acknowledgement. A meaningful changed answer is debounced/coalesced; no request is sent for every keystroke. Target durability is ≤ 5 seconds under the agreed healthy-network profile.

Each AttemptAnswer has a monotonic answer-level revision. A save includes the expected revision. The RPC serializes against the parent Attempt state and performs compare-and-set:

~~~text
Stored revision 7
Tab A sends expected 7 → accepted; answer and revision 8 commit
Tab B sends expected 7 → conflict; no overwrite
~~~

A newly absent answer begins at the documented initial revision. The update must also verify caller owns the IN_PROGRESS Attempt and the submitted question belongs to its pinned version. The RPC locks/checks the Attempt so save-versus-submit has a serial order.

A stale write returns an explicit conflict with the latest safe answer/revision or a reference that allows the Student client to fetch it. The client does not silently replace the server answer. It shows a clear stale-tab state and offers deterministic reload/reconciliation. A stable write/request identity may be used to recognize response-loss retries, but it does not permit overwriting a later revision.

When another tab submits first, every later answer write is rejected as Attempt submitted. Refresh/reopen loads canonical submitted state. Local pending answers are not described as saved until acknowledged. Browser storage may help recover unsent text but is not durable authority.

## 7. Canonical final submission

All Student submit requests route through Worker → one database transaction. Multiple clicks, two tabs and retries after a lost response converge on one result.

The transaction locks the Attempt row (or uses an equivalent conditional state transition), verifies owner and current state, and:

- if IN_PROGRESS: transitions once to SUBMITTED, sets one submitted_at from database time, freezes further answer writes, calculates trusted objective grading, creates the unique result/grade state and required audit atomically;
- if already SUBMITTED/GRADED: returns the canonical persisted state/timestamp/result without another grading execution;
- if not owned or invalid: denies without mutation.

The one-Attempt unique constraint, one-result-per-Attempt constraint, guarded state transition and transaction are sufficient for the MVP invariant; a separate general idempotency service is not required. A request ID may be accepted for tracing, but the database state is the idempotency authority. A transaction rollback leaves no partial canonical submission; a successful transaction cannot be applied twice.

No Student update, even with a stale token, may change answers after commit. A submit race with autosave serializes: either the accepted save precedes submission and is included, or submission precedes it and the save is rejected.

## 8. Objective and manual grading

All grading is server-authoritative and based on persisted answers plus the Attempt's immutable version.

### Objective grading

- Multiple Choice: exact configured correct option.
- Multiple Select: all-or-nothing exact set match in MVP; partial credit requires a future explicit change.
- True/False: exact boolean match.
- Numeric: exact comparison after deterministic normalization; no tolerance, unit conversion or formula evaluation.

Recommended Numeric normalization for MVP: accept a plain decimal string with optional leading sign and decimal separator, trim surrounding whitespace, canonicalize leading zeros/trailing fractional zeros and negative zero, then compare decimal values without binary floating-point rounding. Reject grouping separators, exponent notation, units, NaN/infinity and malformed values. Locale conversion is not implicit; the UI documents accepted format. Any broader parsing requires a product decision and test vectors.

Objective score is computed in the same transaction as canonical submission for bounded MVP assessments. Never accept client-computed points or total score.

### Manual grading

Short Answer and Paragraph/Essay enter awaiting-manual-grade state. An assigned Teacher submits per-question points and feedback through a Worker transaction. The transaction checks assignment, score bounds against the versioned Question points, and records an append-only GradeRevision/GradeRevisionItem set plus grade.manual_change audit. A Teacher cannot modify an old grade revision in place. Manual grading changes only the relevant committed revision; objective scores are preserved.

The Attempt becomes GRADED when the current grading requirements are complete. Result visibility remains governed separately by explicit release.

## 9. Result release and disclosure

An unreleased result is not Student-readable. Teacher release is an explicit Worker/database transaction that verifies assigned Course and grading completeness, selects the exact current GradeRevision, updates the released pointer/state and writes result.release audit.

Default Student disclosure contains score and Teacher feedback only. It excludes protected answer keys and the Assessment's trusted scoring interpretation. If a released result is corrected, keep the old release pointer for traceability but mark the result REVIEW_REQUIRED; Student reads are denied while review is required. Only explicit Teacher re-release after review points to the new revision and writes result.rerelease audit. A changed score is never silently shown.

## 10. Correction and retry-safe regrade

Correction targets a published version's grading interpretation, not its historical content. A Correction record stores actor, reason, affected versioned Questions, before interpretation, corrected interpretation, creation timestamp and affected work. The original AssessmentVersion and protected key snapshot remain unchanged.

A regrade run identifies the correction and affected Attempts. For each Attempt, in a transaction:

- verify it used the corrected version and has not already been processed for this run;
- recalculate only affected objective items from persisted answers;
- preserve all manual-grade items unchanged unless an explicit audited Teacher override is part of the correction;
- append a new complete GradeRevision with score delta and correction/run reference;
- create one unique regrade-run/Attempt outcome;
- set previously released changed Results to REVIEW_REQUIRED without advancing the released revision pointer;
- write assessment.regrade audit with counts and safe summary.

Unique (run_id, attempt_id) plus a transactional processed marker makes retries safe. Do not update prior score revisions. Unchanged results can retain their released state if no grade change occurred. Changed released results require review and explicit re-release.

For the pilot, bounded regrades run synchronously with bounded affected Attempts and a transaction per affected Attempt plus durable run records. If measured scope exceeds safe Worker/PostgreSQL limits, chunk a persisted run through an explicitly introduced queue/continuation mechanism; each Attempt remains atomic and retry-safe. Queueing is a later scale decision, not permission for partial untracked writes.

## 11. Audit and transaction boundaries

AuditEvent is an academic record, not a debug log. Required actions include:

- assessment.publish, assessment.correction.create, assessment.regrade;
- grade.manual_change, grade.override;
- result.release, result.rerelease;
- user.disable, teacher.assign;
- student.enroll, student.unenroll.

An audit event records actor identity/role snapshot, school, action, target, timestamp, reason where required, redacted before/after summary and correlation context. State-changing operation and required audit row commit or roll back together wherever practical. Do not store complete answer payloads, answer keys, authentication secrets or oversized serialized records in audit summaries.

## 12. Required transactional RPC boundaries

Each RPC has a narrow typed contract and enforces current ownership/state; there is no generic SQL endpoint.

| Operation | Atomic boundary |
|---|---|
| publishAssessment | draft validation, version + child snapshots, current pointer, audit |
| startAttempt | eligibility, current version binding, unique Attempt insert |
| saveAttemptAnswer | owner/state check, expected-revision comparison, answer mutation and revision |
| submitAttempt | conditional canonical state/time, answer freeze, objective grading, unique result and audit |
| commitManualGrade | assignment/score check, new revision/items, grading state and audit |
| releaseResult / rereleaseResult | selected current revision, visibility pointer/state and audit |
| createCorrection | immutable correction/affected Questions and audit |
| applyRegradeAttempt | exactly-once per run/Attempt, append grade revision/delta, review state and audit |
| requestUpload / completeUpload | ownership authorization, generated key/metadata and lifecycle |

The Worker authenticates and performs early authorization. The database transaction rechecks relevant authorization and domain state to close races. Prefer invoker security and user JWT/RLS identity; any narrowly scoped definer function must have pinned search_path, qualified objects, revoked public execution and explicit actor/school/resource checks.

## 13. Required race, security and integrity tests

- Two simultaneous publication requests create one version for one draft revision or a deterministic conflict; no partial version or missing audit.
- Attempt starts concurrent with republish: each Attempt references exactly the current version at its commit point.
- Same Student starts twice or in two tabs: one Attempt only; retry returns the canonical Attempt.
- Cross-school or wrong-Course Student start is denied by Worker and database constraints.
- Student projections omit keys before and after publication; direct key table/RPC access is denied.
- Two tabs save the same revision: one succeeds, one conflicts; stale payload never wins silently.
- Answer save racing final submit serializes; no answer mutation occurs after SUBMITTED.
- Double-click, response-loss retry and two-tab submit produce one submitted_at, one result and one objective grading effect.
- Client-provided score, role, owner, version ID or submitted_at cannot influence authoritative state.
- Manual grade is bounded, auditable and append-only; regrade preserves it.
- Regrade retries do not duplicate revision or score delta.
- Correction does not mutate any AssessmentVersion/Question/key row.
- Changed released result becomes REVIEW_REQUIRED and is not silently visible; explicit re-release changes the release pointer and emits audit.
- Student cannot read another Student's Attempt or unreleased result; unassigned Teacher and cross-school Admin cannot act.
- Availability boundary uses database time; CLOSED blocks starts but preserves active Attempts; ARCHIVED does not erase history.
- Autosave meets ≤ 5 seconds durable persistence under the agreed healthy-network profile, including representative concurrency and database failure/retry cases.
