# anti-slop Provenance

- Upstream: [dmmulroy/anti-slop](https://github.com/dmmulroy/anti-slop)
- Reviewed source revision: `c44ef22ca116d0ba62a3ff663a0bd13a3f3fa40b`
- Installation path: local `install-anti-slop` skill under `.agents/skills/`; plugin and required nested reference/license files are vendored here as upstream documents.
- Runtime: `oxlint` and `@oxlint/plugins` are pinned to `1.85.0` in the root dependency catalog.
- License/provenance files accompanying the vendored plugin are retained.

`oxlint.config.ts` enables the upstream rules as errors, except:

- `anti-slop/no-unknown-parameters` is disabled because the Worker JSON helper accepts and serializes `unknown` without inspecting it. The rule would reject a safe response boundary.
- `anti-slop/require-readable-spacing` is disabled because Prettier is the repository formatter and this rule would require unrelated blank-line churn throughout already valid Foundation code.

These are deliberate project exceptions, not general exemptions. Re-evaluate them if the affected code or formatter changes. Do not run blanket autofixes against the repository.
