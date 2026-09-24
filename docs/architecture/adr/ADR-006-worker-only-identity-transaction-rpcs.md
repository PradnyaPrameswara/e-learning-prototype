# ADR-006: Restrict Identity Mutation RPCs to the Trusted Worker

## Status
Accepted for the Identity + Academic Structure implementation.

## Date
2026-09-25

## Context
ADR-003 assigns school structure changes, membership administration, Teacher assignment and Student enrollment to the Worker plus one transactional database operation. PostgreSQL must perform each mutation and its audit event atomically. Supabase exposes functions in `public` through PostgREST; granting `authenticated` execute would let a browser call the same RPC directly and skip Worker request validation, authorization logging and operational controls. Using a caller JWT inside the RPC preserves SQL authorization but cannot enforce the documented Worker route boundary.

## Decision
The Worker authenticates the incoming Supabase bearer token and queries the caller's active school membership and Admin role using its request-scoped user client and RLS. Only after authorization succeeds does it call one of the explicitly named identity RPCs with a separate server-only Supabase service-role client. The Worker derives the actor UUID from the verified Auth response; request JSON never supplies it.

Each RPC accepts that actor UUID, rechecks that the actor currently holds an active Admin membership in the target active school, and performs the school-scoped mutation and audit insert in one PostgreSQL transaction. Function execution is revoked from `PUBLIC`, `anon`, `authenticated` and `service_role` by default, then granted to `service_role` only for the named RPCs. Authenticated users cannot execute them directly. The service client is not used for general table reads or writes. RLS remains enabled and mandatory for all browser-accessible table paths.

## Alternatives considered

### Grant the RPCs to `authenticated` and rely on SQL checks
Rejected for these operations because it permits direct browser invocation and bypasses the Worker boundary required by ADR-003, even though the SQL role check would still prevent unauthorized mutations.

### Use the user's JWT for the mutation RPC
Rejected because the public PostgREST RPC remains callable directly with that same JWT; it cannot distinguish a Worker request from a browser request.

### Give the Worker broad service-role table access
Rejected. Worker code must call only the named transaction RPCs. Direct table DML stays unavailable to authenticated browser roles, and implementation review must verify no general service-client query path is added.

## Consequences
- `SUPABASE_SERVICE_ROLE_KEY` is required only in the Cloudflare Worker secret store and local Worker-only development variables; it must never be present in Astro environment configuration or browser output.
- The Worker performs an RLS-scoped Admin check before creating a service-client call. The RPC repeats the current-state check inside the transaction to close role-revocation races.
- A compromised Worker secret has broad Supabase impact; keep it isolated, rotate it on exposure, and keep the service client usage narrow and auditable.
- PostgreSQL tests must prove direct authenticated RPC calls fail, service-role RPC calls succeed only for a currently authorized actor, and cross-school actors/targets fail.
- Browser table reads continue to use RLS. RLS is not disabled or replaced by this decision.

## Revisit triggers
Revisit if Supabase provides a supported, verifiable Worker-only database identity that can execute narrow transactional RPCs without a service-role key, or if the trusted Worker boundary changes. Any replacement must preserve direct-call denial, current actor/school checks, atomic audit, and the RLS allow/deny suite.
