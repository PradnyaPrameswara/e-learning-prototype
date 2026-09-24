# Engineering Foundation

This document describes how to install and operate the repository foundation. Architecture and product decisions remain in the [planning contract](../planning/PLANNING_CONTRACT.md) and [architecture specifications](../architecture/).

## Requirements and versions

- Node.js 22.23.3 or a compatible Node 22 release, pinned for reproducibility in `.node-version`. This is above Astro/Vite's floor and satisfies the current Astro ESLint plugin runtime requirement.
- pnpm 11.27.1, pinned by the root `packageManager` field and used explicitly in CI.
- Stable workspace tool versions are centralized in `pnpm-workspace.yaml` catalogs and locked in `pnpm-lock.yaml`.
- The initial app toolchain is Astro 7.3.4, React 19.3.0, TypeScript 6.0.3, Tailwind CSS 4.3.3, and Vite 8.3.0.
- Worker tooling is Wrangler 4.137.0, Vitest 4.1.11, and `@cloudflare/vitest-plugin` 1.2.4. Cloudflare's plugin documents a Vitest 4.1+ integration; Vitest 5 is not in the compatible peer range.
- Supabase CLI is 2.117.0. The future Supabase JS client boundary is 2.117.1; it is not installed until authentication/data code has a real owner.
- TanStack Form 1.33.5, Zod 4.6.5, and shadcn CLI 4.21.0 are recorded as selected compatible versions, but are not installed without a real form, contract, or component. The shadcn primitive path is Base UI and must be checked for zero `@radix-ui/*` dependencies.
- ESLint 10.11.0, `@eslint/js` 10.0.1, and `eslint-plugin-astro` 3.1.0 provide the current Astro lint path. Their Node floor is why the repository pins Node 22.23.3 rather than the older machine runtime observed when Foundation began.

The exact selected versions are centralized in the workspace catalog:

| Area                                      | Version                                                        | Foundation use                                                                  |
| ----------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Astro / React integration / check         | Astro 7.3.4 / `@astrojs/react` 7.0.0 / `@astrojs/check` 0.9.10 | Installed in each Astro app                                                     |
| React / React DOM                         | 19.3.0                                                         | Installed in each Astro app for the island integration                          |
| TypeScript / Vite                         | 6.0.3 / 8.3.0                                                  | Installed; TypeScript 7 is not used because Astro 7.3.4 does not yet support it |
| Tailwind CSS / Vite plugin                | 4.3.3 / 4.3.3                                                  | Installed in each app with Tailwind's official Vite integration                 |
| TanStack Form / Zod                       | 1.33.5 / 4.6.5                                                 | Catalog only until a real form or shared schema exists                          |
| shadcn CLI / primitive path               | 4.21.0 / Base UI                                               | Catalog only; initialize when a real shared component is selected               |
| Supabase CLI / JS client                  | 2.117.0 / 2.117.1                                              | CLI installed; client catalog only until auth/data code has an owner            |
| Wrangler / Workers Vitest plugin / Vitest | 4.137.0 / 1.2.4 / 4.1.11                                       | Installed in the Worker; plugin peer range is Vitest 4.1+                       |
| Turborepo / pnpm                          | 2.11.3 / 11.27.1                                               | Installed / pinned package manager                                              |
| ESLint / Astro plugin / TypeScript ESLint | 10.11.0 / 3.1.0 / 8.70.1                                       | Installed shared flat lint configuration                                        |
| Prettier / Astro plugin / Tailwind plugin | 3.9.9 / 1.0.1 / 0.8.1                                          | Installed root formatting baseline                                              |

Version checks were made against official [Astro integration](https://docs.astro.build/en/guides/integrations-guide/react/), [Astro styling](https://docs.astro.build/en/guides/styling/), [Cloudflare Workers Vitest](https://developers.cloudflare.com/workers/testing/vitest-integration/), [Supabase CLI](https://supabase.com/docs/guides/cli), [shadcn Base UI](https://ui.shadcn.com/docs/installation/base), and package release/peer metadata on 2026-09-24. Recheck current compatibility before deliberate upgrades.

## Install and root commands

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm dev:student
pnpm dev:teacher
pnpm dev:admin
pnpm dev:worker
pnpm build
pnpm lint
pnpm typecheck
pnpm test
pnpm check:constraints
pnpm format:check
```

The three Astro apps use separate local ports. `pnpm dev` starts all four workspaces. React is configured as an available island integration; no client router or product screen is scaffolded.

## Package and dependency ownership

- `apps/student`, `apps/teacher`, and `apps/admin` own their routes and app composition.
- `apps/worker` owns narrow trusted HTTP orchestration and future Worker bindings.
- `packages/ui` owns role-neutral presentation assets and the future Base UI shadcn source.
- `packages/schemas` owns shared Zod transport contracts once a real consumer exists.
- `packages/database` owns generated DB types and narrow DB helpers.
- `packages/auth` owns reusable Supabase Auth/session helpers.
- `packages/domain` owns pure deterministic domain rules only when reuse is established.
- `packages/config` owns shared compiler/linter settings.

Apps may depend on shared packages. Shared packages may never depend on apps; apps may never import each other. Do not add `utils`, `common`, or other catch-all packages. Foundation records intended ownership, but does not manufacture empty source modules.

## Supabase local setup

Install Docker Desktop/Engine and start the local stack:

```sh
pnpm db:start
pnpm db:stop
pnpm db:reset
pnpm db:test
pnpm db:types
```

The Supabase CLI project configuration is in `supabase/config.toml`. No product migration exists yet. `db:types` deliberately fails until a reviewed SQL migration exists, then asks the local CLI to generate `packages/database/src/database.types.ts`. This directory is the single migration authority; dashboard-only schema edits are not accepted.

## Environment variables and credentials

Copy `.env.example` only for future browser-safe public Supabase configuration. `PUBLIC_` values can reach Astro browser bundles and must contain only the Supabase URL and publishable key. Copy `apps/worker/.dev.vars.example` to `apps/worker/.dev.vars` for local Worker values; the latter is ignored. Service-role keys, database passwords, R2 access keys, and other private credentials must be Worker-only secrets and must never enter Astro public variables or source control. The examples intentionally contain placeholders, not credentials.

The Wrangler `FILES_BUCKET` binding uses a clearly named local placeholder. It does not provision a Cloudflare bucket and there are no upload/download routes.

The Worker opts out of Cloudflare's date-enabled Node.js compatibility flags because its foundation uses standard Web APIs and has no runtime Node API requirement. Revisit this only if an adopted Worker dependency proves it needs a supported Node API; do not enable Node compatibility by habit.

## Worker development and health smoke test

```sh
pnpm dev:worker
```

`GET http://127.0.0.1:8787/health` returns a minimal liveness response with a request ID; it does not claim Supabase or R2 readiness. Other paths return safe 404 responses; the health route rejects non-GET methods. Errors do not return stack traces or environment data. The handler is tested under Cloudflare's Workers runtime through `@cloudflare/vitest-plugin`.

## Frontend and UI constraints

Astro is the rendering/routing foundation. Use React only for genuinely interactive islands. First-party React code must not directly call `useEffect`, including under an alias or a React namespace. The executable constraint checker also rejects direct Radix imports/dependencies, React Hook Form, Formik, app-to-app imports, package-to-app imports, and workspace dependency cycles.

TanStack Form plus Zod is the planned interactive form standard; native Astro/server forms remain preferable when they are sufficient. No example form is added here. Tailwind CSS 4 is configured through its Vite plugin and shared CSS entry point. shadcn components are not generated until a real component is selected; use the Base UI path and review generated dependencies before adding them.

## CI and deployment boundary

GitHub Actions installs from the committed lockfile and runs constraints, lint, typecheck, tests, and builds without production secrets. Wrangler `build` uses a dry run; no application is deployed by this issue. The structure is intended to map to Cloudflare Pages for Astro static output, Cloudflare Workers for trusted API routes, Supabase for Auth/PostgreSQL, and private R2 for files. Do not treat free-tier quotas as a capacity or SLA guarantee; follow the planning contract's re-verification and pilot validation requirements.
