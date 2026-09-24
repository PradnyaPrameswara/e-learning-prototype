# ADR-002: Use Supabase Auth with PostgreSQL RLS and Trusted Worker Checks

## Status
Accepted

## Date
2026-09-24

## Context
The applications need one identity authority across Student, Teacher and Admin experiences. School roles, account status, Teacher assignment and Student enrollment are mutable school-scoped facts. Frontend role checks cannot enforce security. The system also has browser reads that can be safely constrained by PostgreSQL and privileged Assessment transitions that need trusted orchestration.

## Decision
Use Supabase Auth as the sole authentication provider. Map the Supabase Auth user UUID to profiles.id. Store school membership, active/disabled status and explicit role rows in PostgreSQL; store Teacher assignment and Student enrollment as explicit relations. Do not make user-editable Auth metadata authoritative for school role or scope.

Use verified Supabase sessions for Astro applications and Supabase bearer access tokens to authenticate Worker API requests. Worker validates token signature/issuer/audience/expiry and reloads current membership/role/scope from PostgreSQL. Supabase JWT role claims may identify the database API role, but application roles are resolved from current protected membership rows.

Require PostgreSQL RLS and least-privilege grants for browser-accessible records. Worker performs trusted authorization for privileged actions; transactional database functions recheck ownership and state. Use user JWT/RLS context for user-owned operations where practical. Keep service-role credentials server-only and restrict them to narrow administrative Auth operations that cannot use user authority, with independent authorization and audit.

## Alternatives considered

### Worker-managed identity/password system
Would add credential storage, account recovery, session security, verification and operational responsibility that Supabase Auth already supplies.

### Laravel Auth or custom JWT authority
Would introduce a second identity system and contradict the selected free-first TypeScript Worker architecture.

### Frontend role checks as authority
Rejected because browser state and resource identifiers are attacker-controlled.

### RLS as the sole boundary with no Worker checks
Rejected for privileged Auth APIs and multi-step/transactional workflows; authorization and domain transitions still need trusted orchestration.

## Consequences
- Applications share one Auth identity but cannot assume a single school role from a client claim.
- Every protected request must evaluate current membership and resource scope.
- SSR auth refresh, cookie security, CSRF and cache behavior require integration tests.
- RLS policies, grants, functions and views must be tested with representative authenticated users and denial cases.
- The Worker must not use a broadly privileged credential as a shortcut around per-user authorization.
- Disabling a school membership revokes school capabilities based on current database state without necessarily banning the Auth identity from every other school.

## Revisit triggers
Reconsider only if Supabase Auth cannot meet a documented identity requirement, a future product adopts a different identity provider, or measured policy complexity cannot be maintained. Any change requires one clearly authoritative identity/session model, an ADR and Planning Contract update.
