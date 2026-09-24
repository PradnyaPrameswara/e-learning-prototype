# ADR-001: Keep the Free-First TypeScript Worker Architecture

## Status
Accepted

## Date
2026-09-24

## Context
The product is a school-scoped LMS whose correctness depends on school isolation, trusted Assessment publication, durable Attempts, canonical grading and auditable correction. The initial deployment must fit a cost-conscious free-first strategy. Frontends are already planned as Astro, React and TypeScript; Supabase Auth and PostgreSQL with RLS and private Cloudflare R2 are the selected managed services. The Laravel alternative was evaluated, but the free-tier feasibility evidence did not establish a reliable strict-free PHP host appropriate for real Student grading. The active decision in the Planning Contract is KEEP_TYPESCRIPT_WORKER_FOR_FREE_TIER.

## Decision
Use a TypeScript Cloudflare Worker as the narrow trusted API/orchestration boundary, with Astro applications on Cloudflare Pages where appropriate, Supabase Auth, Supabase PostgreSQL/RLS and private Cloudflare R2.

Do not introduce Laravel, Go, Rust, a second business-logic backend, Redis, Kafka, Kubernetes or microservices for MVP. Keep static and read-oriented app pages Astro-first; use React only for genuinely interactive workflows. Keep the Worker for privileged, sensitive and transactional operations rather than proxying every query.

Free allowances are deployment constraints that must be reverified; they are not capacity or availability guarantees. The 100-concurrent-Attempt profile and required backup/restore drill remain deployment gates.

## Alternatives considered

### Laravel API with Supabase PostgreSQL
Provides mature server-side domain and queue patterns, but the strict-free evaluation did not find a qualifying reliable free Laravel host. A separate always-available PHP host adds cost/operations and duplicates the planned TypeScript application language/contracts. Reconsider only if paid hosting is acceptable or measured domain complexity exceeds the Worker model.

### Go or Rust API
Would add language/toolchain and contract boundaries without an evidenced workload that requires them. Benchmark advantages do not offset maintenance and deployment cost for this MVP.

### Direct Supabase calls for every operation
Would make transactional workflows, privileged Auth operations, R2 authorization and trusted grading difficult to express safely as independent browser requests.

### Worker as a proxy for every database query
Would duplicate straightforward RLS-safe data paths, increase latency and consume Worker requests without a demonstrated security benefit.

## Consequences
- TypeScript is shared across apps, Worker, schemas and domain contracts.
- PostgreSQL remains the transactional authority for cross-row invariants.
- RLS protects direct user-scoped paths; Worker checks current authorization for privileged workflows.
- Deployments must measure 10 ms Worker CPU, database limits, autosave durability, submit races and real R2 behavior.
- The team must preserve strict separation between browser-safe projections and protected answer/scoring data.
- A paid-tier upgrade should first increase allowances for the same services rather than add another backend.

## Revisit triggers
Reopen only with an ADR and Planning Contract update if paid backend hosting becomes acceptable, the Worker cannot safely/maintainably express measured domain needs, large imports/reports/regrades require a separate runtime, or provider limits prevent the validated pilot. Reevaluate workload and operational evidence before choosing a new runtime.
