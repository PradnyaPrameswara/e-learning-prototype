# E-learning Prototype

A clean rebuild of a school-scoped LMS with first-class Assessment integrity. This repository is in engineering-foundation work; the neutral app shells are not product features.

## Get started

Requirements and exact tool versions are documented in [Foundation operations](docs/foundation/FOUNDATION.md).

```sh
pnpm install --frozen-lockfile
pnpm dev
```

Useful checks:

```sh
pnpm build
pnpm lint
pnpm typecheck
pnpm test
pnpm check:constraints
```

See the [active planning contract](docs/planning/PLANNING_CONTRACT.md) and [architecture documents](docs/architecture/) for product and system decisions.

## Local Supabase

Docker is required for the local Supabase stack. Use `pnpm db:start` after the schema implementation issue introduces reviewed migrations. There is intentionally no product schema in this foundation.
