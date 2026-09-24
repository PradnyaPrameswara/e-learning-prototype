# ADR-004: Publish Immutable Assessment Versions

## Status
Accepted

## Date
2026-09-24

## Context
Students may begin or submit an Assessment while Teachers continue editing. If an Attempt reads mutable question/key rows, later edits can change what the Student saw or how a historical response is scored. Correction must preserve the published academic record while allowing a transparent grade correction.

## Decision
Keep mutable draft content separate from immutable AssessmentVersion snapshots. Publication validates readiness and atomically snapshots Assessment settings, ordered Questions, options, scoring and protected answer keys, updates the current-version pointer and writes the audit event. Every Attempt stores a permanent reference to the exact version it started from; it never points to draft content.

Publishing a new version while older Attempts remain IN_PROGRESS is allowed. Existing Attempts continue against their original version; new eligible Attempts use the newly current version. The one-Attempt-per-Student-per-Assessment MVP rule means a Student who already started the old version cannot start a second version of the same Assessment.

A correction is a separate immutable event with reason, actor, affected Questions and before/after scoring interpretation. Regrade appends grade revisions and score deltas. It never edits a published version. A changed released result becomes REVIEW_REQUIRED until a Teacher explicitly re-releases it.

## Alternatives considered

### Mutate a published version in place
Rejected because it changes academic history and makes an Attempt's original question/key state unknowable.

### Copy mutable Assessment rows at Attempt start
Rejected as the primary model because it duplicates publication semantics per Student and complicates shared, verifiable version history.

### Freeze all Teacher editing after first publication
Rejected because revisions are needed; a new immutable version preserves both history and authoring flexibility.

### Automatically move active Attempts to the latest version
Rejected because answers and seen prompts would no longer correspond to a stable question set.

## Consequences
- Publication is a database transaction and must have race tests.
- Published child rows and protected keys are append-only.
- Every Attempt's exact version must be checked by foreign keys and transaction logic.
- Student API/UI projections omit all trusted keys and scoring internals.
- Corrections/regrades add history and cannot silently mutate a prior result.
- Test fixtures must include active Attempts spanning multiple published versions.

## Revisit triggers
Any need for Attempt migration, multiple Attempts, resets, retakes or Student movement between versions requires explicit product policy, impact analysis, a new ADR and Planning Contract update. It must not be implemented as a convenience side effect of publishing.
