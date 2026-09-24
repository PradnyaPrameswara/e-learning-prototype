# Domain and architecture documentation

There is no separate glossary or `CONTEXT.md`; do not create one solely to satisfy a skill template. The planning contract and architecture documents are authoritative.

Before product or domain work:

1. Read `docs/planning/PLANNING_CONTRACT.md`.
2. Read the relevant documents in `docs/architecture/` and relevant ADRs in `docs/architecture/adr/`.
3. Preserve established vocabulary, requirements, and constraints. Surface contradictions and unresolved decisions instead of silently inventing a new contract.
4. Add material architecture decisions as ADRs; update the contract when the product baseline changes.

Project documentation belongs under `docs/`. Keep domain-specific behavior in its owning app/package as defined by the architecture; do not use shared packages as a dumping ground.
