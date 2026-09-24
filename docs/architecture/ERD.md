# Entity Relationship Model

**Status:** Implementation-oriented logical ERD; no migrations are defined here.

**Source of truth:** [Planning Contract](../planning/PLANNING_CONTRACT.md).

**Key invariant:** every protected record is school-owned directly or through a database-constrained parent path.

## 1. Conceptual ERD

~~~mermaid
erDiagram
  AUTH_USER ||--|| PROFILE : has
  SCHOOL ||--o{ SCHOOL_MEMBERSHIP : contains
  PROFILE ||--o{ SCHOOL_MEMBERSHIP : joins
  SCHOOL_MEMBERSHIP ||--o{ MEMBERSHIP_ROLE : has
  SCHOOL ||--o{ ACADEMIC_YEAR : defines
  SCHOOL ||--o{ CLASS : defines
  SCHOOL ||--o{ SUBJECT : defines
  ACADEMIC_YEAR ||--o{ COURSE : scopes
  CLASS ||--o{ COURSE : hosts
  SUBJECT ||--o{ COURSE : teaches
  SCHOOL_MEMBERSHIP ||--o{ TEACHER_ASSIGNMENT : teacher
  COURSE ||--o{ TEACHER_ASSIGNMENT : assigned
  SCHOOL_MEMBERSHIP ||--o{ STUDENT_ENROLLMENT : student
  CLASS ||--o{ STUDENT_ENROLLMENT : enrolls
  ACADEMIC_YEAR ||--o{ STUDENT_ENROLLMENT : year
  COURSE ||--o{ LESSON : contains
  LESSON ||--o{ LESSON_BLOCK : composes
  COURSE ||--o{ MEDIA_ASSET : owns
  ASSESSMENT ||--|| ASSESSMENT_DRAFT : edits
  ASSESSMENT ||--o{ ASSESSMENT_VERSION : publishes
  ASSESSMENT_DRAFT ||--o{ DRAFT_QUESTION : contains
  DRAFT_QUESTION ||--o{ DRAFT_OPTION : offers
  DRAFT_QUESTION ||--o| DRAFT_ANSWER_KEY : protects
  ASSESSMENT_VERSION ||--o{ VERSION_QUESTION : snapshots
  VERSION_QUESTION ||--o{ VERSION_QUESTION_OPTION : offers
  VERSION_QUESTION ||--o| PROTECTED_ANSWER_KEY : protects
  COURSE ||--o{ ASSESSMENT : owns
  SCHOOL_MEMBERSHIP ||--o{ ATTEMPT : student
  ASSESSMENT_VERSION ||--o{ ATTEMPT : binds
  ATTEMPT ||--o{ ATTEMPT_ANSWER : records
  ATTEMPT ||--o| RESULT : has
  RESULT ||--o{ GRADE_REVISION : revises
  GRADE_REVISION ||--o{ GRADE_REVISION_ITEM : scores
  ASSESSMENT ||--o{ ASSESSMENT_CORRECTION : corrects
  ASSESSMENT_CORRECTION ||--o{ CORRECTION_QUESTION : covers
  ASSESSMENT_CORRECTION ||--o{ REGRADE_RUN : triggers
  REGRADE_RUN ||--o{ REGRADE_ATTEMPT : processes
  SCHOOL ||--o{ AUDIT_EVENT : records
  SCHOOL_MEMBERSHIP ||--o{ AUDIT_EVENT : actor
~~~

The diagram is conceptual; composite foreign keys described below are required where the diagram shows a relation across school-owned data.

## 2. Identity and academic structure

### School and identity

- **schools**: UUID primary key, name, status, timestamps. Root owner for school data.
- **profiles**: UUID primary key equal to Supabase Auth user ID; safe display/profile fields only. Unique FK to auth.users. No authoritative role fields in editable profile metadata.
- **school_memberships**: UUID primary key, school_id, user_id, status (active/disabled), joined/disabled timestamps. Unique (school_id, user_id). A user may belong to more than one school in future.
- **membership_roles**: membership_id, school_id, role (admin/teacher/student), status/timestamps. Unique (membership_id, role). Separate rows allow explicit multiple roles without implying that Admin grants Teacher permissions. Role/status modifications are trusted and audited.

### Academic records

- **academic_years**: UUID, school_id, label, date range, status. Unique (school_id, id) and unique school/year label as appropriate.
- **classes**: UUID, school_id, stable school class/cohort label, grade/section fields and status. Unique (school_id, id).
- **subjects**: UUID, school_id, name/code, status. Unique (school_id, id), and a school-scoped code uniqueness rule if codes are used.
- **courses**: UUID, school_id, academic_year_id, class_id, subject_id, title/display settings and lifecycle. A Course is the subject offering for one class in one academic year. Unique (school_id, id) and unique (school_id, academic_year_id, class_id, subject_id). Composite FKs require all referenced academic records to have the same school. A class can recur in later years; the Course binds it to the year.

### Assignment and enrollment

- **teacher_assignments**: UUID, school_id, course_id, teacher_membership_id, status, assigned_by, timestamps. Unique active assignment for (course_id, teacher_membership_id); retain disabled/revoked history or record the change in audit. Composite FKs bind teacher membership and Course to the same school. The trusted operation also verifies the membership has the active Teacher role.
- **student_enrollments**: UUID, school_id, academic_year_id, class_id, student_membership_id, status, enrolled_by, timestamps. A partial unique constraint permits at most one active class enrollment per Student membership and academic year while retaining old class rows for history. Composite FKs prove year, class and membership share the school. MVP Course access is derived from the enrolled class/year's Courses; a separate Course-enrollment table is deferred unless electives or course-specific enrollment become real requirements. Enrollment history is retained for historical Attempts.

## 3. Learning content and files

- **lessons**: UUID, school_id, course_id, title, ordering, status (draft/published/archived), published_at and timestamps. Composite FK (school_id, course_id).
- **lesson_blocks**: UUID, school_id, lesson_id, ordering, block_type and validated JSON payload. Unique (lesson_id, ordering); parent FK carries school ownership. Supported payload types are defined by product schema, not by arbitrary HTML.
- **media_assets**: UUID, school_id, course_id, uploader_membership_id, generated object key, original display name, detected content type, byte size, checksum if available, attachment purpose, lifecycle status and timestamps. Unique object key. Composite FKs bind course and uploader membership to the same school. Binary data is only in private R2; deletion/retention behavior is a later implementation detail.

## 4. Assessment authoring and immutable publication

- **assessments**: UUID, school_id, course_id, creator membership, lifecycle state, availability/due timestamps, current_published_version_id (nullable), timestamps. Assessment identity and current operational settings live here. Composite FK binds its Course to school.
- **assessment_drafts**: one mutable current draft per Assessment, unique assessment_id. Holds draft settings and revision counter. A future edit after publication changes this draft only.
- **draft_questions**: UUID, school_id, assessment_id, stable draft ordering, type, prompt/content schema, points (> 0), scoring configuration and timestamps. This is mutable authoring state.
- **draft_options**: UUID, school_id, draft_question_id, ordering and safe option content. Unique question/order.
- **draft_answer_keys**: separate protected mutable keys/scoring interpretation for draft questions. No Student select grant/policy.
- **assessment_versions**: UUID, school_id, assessment_id, monotonically increasing version_number, immutable settings snapshot, publication actor/time, content digest if useful. Unique (assessment_id, version_number); unique (school_id, assessment_id, id) to support composite references.
- **version_questions**: immutable snapshot of question type, prompt, order, points and scoring metadata. Unique (assessment_version_id, order); stable source draft ID may be retained for traceability but is not used as mutable content.
- **version_question_options**: immutable option snapshot and order. Unique (version_question_id, order).
- **protected_answer_keys**: immutable version-scoped correct answer/scoring representation, isolated from browser grants and safe projections. Use an explicit relation to a version question; never expose the key through a Student query or generic serializer.

Assessment publication snapshots settings, questions, ordering, options, scoring and keys, inserts all snapshot children, changes the current-version pointer and appends the audit event in one database transaction. Failure rolls back the whole publication. Student Attempts reference only AssessmentVersion, never draft rows.

A later published version is a new immutable row. Existing Attempts stay pinned to their version. New eligible Attempts use the current published version. Under the MVP one-Attempt-per-Student-per-Assessment rule, a Student who already has an Attempt cannot start another version of that Assessment.

## 5. Attempt, grading and result history

- **attempts**: UUID, school_id, assessment_id, assessment_version_id, student_membership_id, status (IN_PROGRESS/SUBMITTED/GRADED), started_at, submitted_at, grading state/timestamps. Unique (assessment_id, student_membership_id) enforces the MVP one-Attempt policy. Composite FKs prove the Assessment, exact version, Student membership and Course belong to the same school and that the version belongs to the Assessment. Index by (student_membership_id, status), (assessment_id, status), and (school_id, submitted_at).
- **attempt_answers**: UUID or composite primary key (attempt_id, version_question_id), answer payload, answer_revision, updated_at. Unique (attempt_id, version_question_id). A composite FK proves the question belongs to the Attempt's AssessmentVersion. Parent Attempt lock/CAS serializes autosave with submission. Do not persist a client score.
- **results**: one row per Attempt, unique attempt_id, school_id, state (not released/released/review required), current_grade_revision_id and released_grade_revision_id, timestamps. Separate current and released pointers preserve what the Student has actually been told.
- **grade_revisions**: append-only result revision number, source (objective/manual/correction/override), total score, feedback summary, actor/reason as appropriate, created_at. Unique (result_id, revision_number). No in-place update of a prior revision.
- **grade_revision_items**: immutable per-question points awarded, feedback, grading source and relevant rationale, keyed to grade revision and version question. Manual grade rows are carried forward unchanged in later automatic correction revisions unless a Teacher explicitly overrides with an audited reason.

Objective grading is computed by trusted database logic during the canonical final-submit transaction for bounded MVP submissions. Subjective questions remain awaiting Teacher grading; a grade revision records the resulting committed grading state.

## 6. Correction, regrade and audit

- **assessment_corrections**: UUID, school_id, assessment_id, source_version_id, actor membership, reason, original interpretation summary, corrected interpretation summary, status, created_at. Immutable correction record. It corrects interpretation for grading; it never edits the published version/key.
- **correction_questions**: correction_id plus version_question_id and structured before/after scoring interpretations; unique correction/question. Scope must be within the referenced version.
- **regrade_runs**: UUID, school_id, correction_id, status, requested/completed times, actor, idempotency identity. A retry resumes/returns the same run rather than duplicating effects.
- **regrade_attempts**: run_id, attempt_id, outcome, prior/new score and delta, grade_revision_id, processed_at. Unique (run_id, attempt_id), which makes application retry-safe.
- **audit_events**: UUID, school_id, actor_user_id, actor_role snapshot, action, target_type/id, before_summary, after_summary, reason, request correlation context and created_at. Store small, redacted summaries, not full Student answers or answer keys. Index by (school_id, created_at desc), and by target/time for academic history.

Required actions include assessment publication/correction/regrade, manual grade change/override, result release/re-release, account disable, Teacher assignment, and Student enrollment/unenrollment. State-changing audit rows are inserted in the same transaction as their state change wherever practical. Audit retention and archival policy remains an implementation/operations decision; events are durable academic records, not debug logs.

## 7. School ownership and cross-school integrity

Every protected root has school_id: academic years, classes, subjects, Courses, assignments, enrollments, Lessons, media, Assessments, versions, Attempts, results, corrections, regrade runs and audit events. Child records either carry school_id as well or have a composite parent key that proves school identity.

Use UUID primary keys consistently. Add UNIQUE (school_id, id) on parent tables referenced through a school composite FK. For same-school references, use composite FKs such as:

- courses (school_id, class_id) → classes (school_id, id);
- courses (school_id, academic_year_id) → academic_years (school_id, id);
- assessments (school_id, course_id) → courses (school_id, id);
- attempts (school_id, assessment_id, assessment_version_id) → a matching Assessment/version ownership key;
- attempts (school_id, student_membership_id) → school_memberships (school_id, id);
- results (school_id, attempt_id) → attempts (school_id, id).

Where a relationship spans multiple parents (Course links year/class/subject), each composite FK independently proves same-school ownership. Trusted RPCs also verify semantic role and lifecycle. Resource IDs never confer permission.

Avoid cascading deletion of academic history. Disable or archive membership and academic records; preserve Attempt, grade, correction and audit rows. Exact retention/legal deletion rules are not defined for MVP and require a future policy decision before implementing destructive account deletion.

## 8. Lifecycle ownership

Persist lifecycle state only where it represents an authoritative transition or historical fact:

- School membership, Teacher assignment and Student enrollment: active/disabled or active/unenrolled with history.
- Lesson: draft/published/archived.
- Assessment: draft/published/closed/archived operational state; readiness is computed from draft content.
- AssessmentVersion: immutable published snapshot; publication time/actor never changes.
- Attempt: IN_PROGRESS → SUBMITTED → GRADED; no Student answer writes after submission.
- Result: current grade revision and separately released revision; released changes require review and explicit re-release.
- Correction/Regrade: durable append-only operation/run state.

Do not persist redundant readiness values if they can drift from draft validation. Due/close behavior is defined in [Assessment Integrity](ASSESSMENT_INTEGRITY.md).

## 9. Index and constraint baseline

In addition to primary/unique keys and the composite FK-supporting unique indexes:

| Table | Recommended index/constraint |
|---|---|
| school_memberships | unique school/user; lookup user + status |
| membership_roles | unique membership/role; lookup active role |
| courses | unique year/class/subject; school + class/year |
| teacher_assignments | active course/teacher uniqueness; course/status and teacher/status |
| student_enrollments | year/student uniqueness; class/status and student/status |
| lessons | course/status/order |
| lesson_blocks | unique lesson/order |
| media_assets | unique object key; course/created time |
| assessments | course/status; availability for course listing |
| assessment_versions | unique Assessment/version number |
| version_questions | unique version/order |
| attempts | unique assessment/student; student/status and assessment/status |
| attempt_answers | unique Attempt/question; Attempt/revision retrieval |
| results | unique Attempt; school/state/release listing |
| grade_revisions | unique result/revision |
| regrade_attempts | unique run/Attempt |
| audit_events | school/created time desc; target type/id/time |

Indexes should match actual query predicates, authorization policy subqueries and pilot measurements. Avoid speculative indexes and unbounded JSON scans. Review query plans and connection behavior before the 100 concurrent Attempt validation profile.

## 10. Deferred schema details

No SQL, migrations, exact JSON schemas, parser test vectors, retention durations, byte limits, or production partitioning are specified here. Numeric exact-match uses the plain-decimal normalization selected in [Assessment Integrity](ASSESSMENT_INTEGRITY.md); implementation must add boundary test vectors and must not silently add units, tolerances or formula evaluation. If the Course enrollment model changes to electives, add explicit enrollment with migration and policy review. These details do not reopen the school ownership, immutable version, Attempt binding or history guarantees.
