# Repository agent guidance

Read `docs/planning/PLANNING_CONTRACT.md` and the relevant files in `docs/architecture/` before product or architecture work. The planning contract and ADRs own product and architecture decisions; do not create competing context documents or silently override them.

## Tool routing

- Use `docs/tooling/AGENT_TOOLING.md` to choose one primary skill or context engine for the current task. Do not load every skill.
- Use Matt Pocock's `grill-with-docs` before ambiguous domain changes; use `grill-me` for focused requirement questions and `to-spec` after scope is understood.
- Use `tdd` where a behavior has a clear seam, `diagnosing-bugs` for defects, and `improve-codebase-architecture` periodically after meaningful phases.
- Use CodeDB for task context and symbols; use Lexa for dependency impact or audit when helpful. Avoid running both for the same question by default.
- Use Addy's API, frontend, security, performance, shipping, and review skills only at their matching stage. `code-review-and-quality` is the project's primary review skill.
- Run anti-slop with normal project lint. Use Caveman to reduce low-value prose while preserving exact code, commands, errors, risks, and validation evidence.
- LSP-AI is optional editor assistance. It is not a substitute for Codex, CodeDB, Lexa, tests, or compiler checks.

## Engineering constraints

Preserve the Astro-first, selective React-island architecture, strict TypeScript, Tailwind CSS 4, TanStack Form, Zod, non-Radix shadcn/ui, and the TypeScript Cloudflare Worker. Do not use direct first-party React `useEffect`, React Hook Form, Formik, app-to-app imports, or `@radix-ui/*`. Supabase Auth, PostgreSQL RLS, and private Cloudflare R2 remain the active platform decisions. Do not add Laravel, Go, Rust, Redis, Kafka, Kubernetes, or another backend without an approved architecture change.

Frontend implementation rules:

- Astro-first; use React only for genuine interactive islands.
- Use TypeScript for application code and Tailwind CSS for styling.
- Shared shadcn/ui components belong in `packages/ui`; use approved non-Radix primitives only.
- Never add `@radix-ui/*`, React Hook Form, or Formik.
- Never call first-party React `useEffect` directly or hide it in a custom hook.
- Do not add legacy implementations or compatibility layers without an explicit current requirement.

## Git workflow

Use `issue → dedicated branch → implementation → validation → PR → human review and merge`. Keep one coherent issue per branch. Do not commit unfinished work, mix unrelated refactors, enable auto-merge, or merge on the user's behalf. Architecture changes require an ADR and planning-contract update before implementation. Keep secrets out of Git and version-control migrations.

Never auto-merge or merge on the user's behalf. Never add `Co-authored-by:` or other AI attribution trailers to commits.
