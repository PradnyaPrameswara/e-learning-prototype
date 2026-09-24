# ADR-007: Lesson Draft Editing and Publication

## Status
Accepted for the Lesson Backend implementation.

## Date
2026-09-25

## Context
The ERD defines a Course-scoped Lesson with draft, published and archived states, while the planning contract requires Student access only to published Lessons and permits RLS-protected Teacher draft CRUD. Lesson publication and lifecycle changes also need a durable audit event. The original authorization matrix allowed a direct one-row publication transition only if that remained sufficient, but the implemented lifecycle includes an atomic state change plus audit and therefore needs the trusted transaction boundary already used by Identity operations.

The content contract calls for structured learning blocks, not a generic page builder. The Assessment domain has not yet been implemented, and media transfer authorization is a separate future operation.

## Decision
- A Lesson row is the mutable identity and current content container; this phase does not add Lesson publication versions.
- An assigned, active Teacher may directly create and edit a Lesson title only while it is draft. Draft block writes are also direct Supabase operations under RLS. Published titles and block content are read-only until explicitly unpublished; an assigned Teacher may still change the sequence position of a non-archived Lesson.
- Publish, unpublish and archive are named Worker-only operations backed by narrow PostgreSQL RPCs. Each operation rechecks the actor's current active Teacher role and exact Course assignment, locks the Lesson, and writes its audit event in the same transaction as the state transition.
- Publication requires at least one valid content block. Unpublishing clears `published_at`, returns the same Lesson to draft, and immediately removes it from Student RLS visibility. Republish records a new publication timestamp and audit event. Archiving is terminal, preserves content and historical timestamps, and removes Student visibility.
- Student read access requires current published state plus active school membership, Student role and current Course enrollment. Admin does not inherit Teacher authoring access.
- Supported blocks are heading, paragraph, image, PDF attachment, external video, formula and callout with strict structured payloads. Arbitrary HTML and Assessment-reference blocks are excluded. Media metadata is private to Worker/service operations; direct browser upload/download and R2 signing are not part of this phase.
- Lesson and block reorder operations use narrowly scoped invoker-rights database functions for atomic full-list changes. They preserve RLS and validate that the submitted order contains every active Lesson or draft block exactly once. The database also permits RLS-scoped sequence-position updates; the unique ordering constraints remain authoritative.

## Alternatives considered

### Directly update publication state from the browser
Rejected because state and audit would not form one trusted transaction and a browser could bypass the required lifecycle/audit path.

### Create immutable Lesson versions like Assessments
Deferred. The planning contract explicitly requires immutable Assessment versions; it does not require Lesson version snapshots. Adding them now would duplicate complexity without a stated Lesson-history requirement. If restoring or comparing prior published Lesson content becomes a real requirement, add versioning through a separate decision before changing this model.

### Permit editing a published title or block content in place
Rejected because Students could observe partially changed Lesson content without a clear publication transition or audit boundary. Course sequence order may change independently because it does not alter a Lesson's content.

### Support Assessment-reference blocks or full media transfer now
Deferred until the Assessment and R2 authorization domains have their own stable contracts.

## Consequences
- The Worker uses the caller's RLS-scoped Lesson read as an early authorization check; the RPC independently checks actor role, assignment and parent Course state before mutation.
- Lifecycle state changes and audit insertion commit or roll back together. Repeating an already-achieved transition returns the canonical Lesson without a duplicate audit event.
- RLS remains the browser authorization boundary for draft content edits, Lesson order changes and published reads. Database foreign keys prevent Lesson, block and media metadata from crossing School/Course ownership.
- Unpublishing affects current Student visibility immediately; this model does not preserve a separately addressable old publication snapshot.
- Concrete media size limits and R2 upload/download workflows remain for a later implementation issue.

## Revisit triggers
Revisit if product requirements need Lesson history/restore, scheduled publication, Assessment references inside Lessons, media transfer in the Lesson workflow, or a lifecycle policy different from explicit unpublish-before-edit. Preserve the current RLS scopes and atomic audit invariant in any replacement.
