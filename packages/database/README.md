# `@lms/database`

Future owner of Supabase-generated TypeScript database types and narrowly scoped database helpers. Types are generated from reviewed local Supabase migrations; do not hand-write generated output or add product tables during Foundation.

Run `pnpm db:types` after a reviewed migration exists and the local Supabase database is running. The command refuses to generate a fake schema when no SQL migrations exist.
